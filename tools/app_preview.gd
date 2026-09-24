extends SceneTree
## Ferramenta: vídeo de prévia da App Store (App Preview), com jogo de verdade.
##
## Quatro cenas na mesma arena, da tarde à noite como numa partida: tiroteio na praça, descida
## pelo trilho, espingarda no braço oeste e a rua residencial à noite. O jogador é "pilotado" por
## um roteiro que usa os CONTROLES DE TOQUE (o joystick e os botões aparecem apertados) e mira
## suave; os bots jogam sozinhos (dificuldade fácil); HUD, sons, tiros e acertos são os do jogo.
##
## Gravação final (o som sai do Movie Maker; os quadros, de uma SubViewport do tamanho exato):
##   Godot --path . -s res://tools/app_preview.gd --resolution 480x270 --always-on-top \
##       --write-movie <pasta>/game.avi --fixed-fps 30 -- <pasta> [iphone|ipad]
##   python3 tools/make_app_preview.py <pasta>     (junta quadros, sons e música num .mp4)
## Rascunho rápido para conferir o roteiro (sem som, 1 quadro em 3, pequeno):
##   Godot --path . -s res://tools/app_preview.gd --resolution 480x270 --always-on-top \
##       --fixed-fps 30 -- <pasta> draft
## Saída: <pasta>/frames/f00000.png... e <pasta>/segments.json (trechos gravados, em quadros do
## Movie Maker, para cortar o som igual ao vídeo). A música fica MUDA na gravação: o
## make_app_preview.py põe a música inteira por cima, sem pulos nos cortes.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const FPS: float = 30.0
## [tamanho do vídeo, tamanho do 2D (a tela de 648 de altura do jogo, esticada)]. A Apple pede
## 1920 x 886 para iPhone deitado (6,5" a 6,9") e 1600 x 1200 para iPad.
const DEVICES: Dictionary = {
	"iphone": [Vector2i(1920, 886), Vector2i(1404, 648)],
	"ipad": [Vector2i(1600, 1200), Vector2i(1152, 864)],
	"draft": [Vector2i(960, 443), Vector2i(1404, 648)],
}
## Duração de cada partida simulada (o céu segue o relógio: 300 s = tarde até a noite).
const MATCH_SECONDS: float = 300.0

var _out: String = ""
var _draft: bool = false
var _view: SubViewport
var _level: Node3D
var _player: Character
var _bots: Array[Character] = []
var _referee: MatchReferee
var _deathmatch: Deathmatch
var _touch: TouchControls
var _joystick: TouchJoystick
var _buttons: Dictionary[StringName, TouchActionButton] = {}

## Quadros do Movie Maker desde o começo (o som do game.avi anda um quadro por vez).
var _movie_frame: int = 0
var _recording: bool = false
var _saved: int = 0
var _segment_start: int = 0
var _segments: Array = []
## Relógio da cena gravada (segundos).
var _clock: float = 0.0

# --- Piloto (decide a cada passo de física) ---
## Para onde olhar: um personagem (peito), um ponto, ou nada (olhar parado).
var _aim_target: Character
var _aim_point: Variant = null
## Rapidez da mira (maior = vira mais rápido; 1/s).
var _aim_rate: float = 8.0
## Atira sozinho quando a mira passa perto do peito do alvo.
var _auto_fire: bool = false
## Bots a derrubar nesta cena (o alvo é o mais perto, de preferência à vista) e quem já caiu.
var _hunt_list: Array[Character] = []
var _hunt_fallen: Dictionary[Character, bool] = {}
## Direção pedida ao joystick (x = direita, y = trás) e a atual (o dedão anda aos poucos).
var _move_goal: Vector2 = Vector2.ZERO
var _stick: Vector2 = Vector2.ZERO
## Botões segurados pelo roteiro (além do tiro automático).
var _held: Dictionary[StringName, bool] = {}
## O piloto só comanda durante as cenas (na preparação o jogador fica parado).
var _pilot_on: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	var device: String = args[1] if args.size() > 1 else "iphone"
	_draft = device == "draft"
	DirAccess.make_dir_recursive_absolute(_out.path_join("frames"))
	for file: String in DirAccess.get_files_at(_out.path_join("frames")):
		DirAccess.remove_absolute(_out.path_join("frames").path_join(file))

	# Som: a música fica de fora (entra inteira na montagem) e o resto no volume cheio.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), 0.0)

	_view = SubViewport.new()
	_view.size = DEVICES[device][0]
	_view.size_2d_override = DEVICES[device][1]
	_view.size_2d_override_stretch = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.msaa_3d = Viewport.MSAA_4X
	_view.audio_listener_enable_3d = true
	root.add_child(_view)
	process_frame.connect(_on_process_frame)
	physics_frame.connect(_on_physics_frame)

	await _load_arena()
	# Terceiro argumento opcional: só algumas cenas (ex.: "24"), para acertar uma de cada vez.
	var only: String = args[2] if args.size() > 2 else "1234"
	if only.contains("1"):
		await _shot_plaza()
	if only.contains("2"):
		await _shot_rail()
	if only.contains("3"):
		await _shot_shotgun()
	if only.contains("4"):
		await _shot_night()

	var file := FileAccess.open(_out.path_join("segments.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "frames": _saved, "movie_frames": _movie_frame,
			"segments": _segments}, "\t"))
	file.close()
	print("DONE frames=%d movie_frames=%d segments=%s" % [_saved, _movie_frame, str(_segments)])
	quit()


func _load_arena() -> void:
	_level = (load(ARENA) as PackedScene).instantiate()
	_view.add_child(_level)
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	_deathmatch = _level.get_node("Deathmatch")
	_touch = _player.get_node("HumanController/TouchControls")
	_touch.force_visible = true
	_joystick = _touch.get_node("Root/Joystick")
	for node: Node in _touch.find_children("*", "TouchActionButton", true, false):
		var button := node as TouchActionButton
		_buttons[button.action] = button
	# O jogador nunca morre no vídeo: a vida não passa de 30 para baixo (o juiz confere a vida
	# DEPOIS de avisar a mudança, então a morte não acontece).
	_player.health_changed.connect(_keep_alive)
	# Ajuda de mira ligada, como no celular.
	_player.command_hook = func(command: CharacterCommand) -> void: command.aim_assist = true
	await _frames(10)
	# Depois do ArenaSetup (que aplica a dificuldade escolhida nas opções).
	var easy: BotDifficulty = load("res://bots/difficulty_easy.tres")
	_bots.clear()
	for node: Node in get_nodes_in_group(&"bots"):
		var bot := node as Character
		(bot.controller as BotController).difficulty = easy
		_bots.append(bot)


# --- Cenas ---

## 1. Tarde dourada na praça: anda para a frente e derruba dois bots com o revólver.
func _shot_plaza() -> void:
	var a: Character = _bots[0]
	var b: Character = _bots[1]
	var c: Character = _bots[2]
	# Entre a ponta do braço sul e o anel de muros da praça: campo aberto, sem onde se esconder.
	await _prepare(0.2, {
		_player: [Vector3(-2.0, 0.1, 20.0), Vector3(-4.0, 0.1, 11.0)],
		a: [Vector3(-4.5, 0.1, 11.0), Vector3(-2.0, 0.1, 20.0)],
		b: [Vector3(5.5, 0.1, 12.5), Vector3(-2.0, 0.1, 20.0)],
		c: [Vector3(9.5, 0.1, 7.0), Vector3(-2.0, 0.1, 20.0)],
	}, [a, b, c])
	_player.apply_look(_player.yaw, deg_to_rad(-4.0))
	_begin_segment()
	_move_goal = Vector2(0.3, -0.7)
	_hunt([a, b, c])
	await _wait(8.0, _hunt_done)
	_hunt([])
	_move_goal = Vector2(-0.3, -1.0)
	_look_at(_player.head.global_position + (-_player.global_basis.z) * 10.0)
	await _wait(0.6)
	_end_segment()


## 2. Pôr do sol: corre até a ponta do braço sul, engata no trilho e desce até o quarteirão leste.
func _shot_rail() -> void:
	await _prepare(0.3, {
		_player: [Vector3(-6.0, 0.1, 17.5), Vector3(10.0, 0.1, 17.5)],
	}, [])
	_begin_segment()
	_move_goal = Vector2(0.0, -1.0)
	_look_at(Vector3(8.0, 3.0, 18.5))
	await _wait(0.6)
	_aim_rate = 6.0
	_look_at(Vector3(3.0, 10.0, 21.0))
	await _wait(0.8)
	await _press(&"use_rail", func() -> bool: return _player.is_on_rail, 1.0)
	_move_goal = Vector2.ZERO
	# Pendurado: olha para a frente e um pouco para baixo (a cidade passando por baixo). Nunca
	# para cima enquanto é puxado: a câmera fica colada no tubo do trilho.
	var ride_start: float = _clock
	while _player.is_on_rail and _clock - ride_start < 6.0:
		var ahead: Vector3 = _player.velocity if _player.velocity.length() > 1.0 else -_player.global_basis.z
		ahead.y = 0.0
		_look_at(_player.head.global_position + ahead.normalized() * 12.0 + Vector3.DOWN * 4.0)
		_aim_rate = 10.0 if _player.is_rail_pulling else 3.0
		_move_goal = Vector2.ZERO if _player.is_rail_pulling else Vector2(0.0, -1.0)
		await process_frame
	_move_goal = Vector2.ZERO
	_aim_rate = 5.0
	_look_at(_player.head.global_position + Vector3(8.0, -3.0, -6.0))
	await _wait(2.0, func() -> bool: return _player.is_grounded())
	await _wait(0.35)
	_end_segment()


## 3. Crepúsculo no braço oeste: pega a espingarda no caminho e derruba o bot que vem da ponte.
func _shot_shotgun() -> void:
	var a: Character = _bots[2]
	await _prepare(0.44, {
		_player: [Vector3(-8.0, 0.1, 6.0), Vector3(-30.0, 0.1, 6.0)],
		a: [Vector3(-21.0, 0.1, 3.0), Vector3(-8.0, 0.1, 6.0)],
	}, [a])
	_begin_segment()
	_move_goal = Vector2(0.0, -1.0)
	_look_at(_player.head.global_position + Vector3(-10.0, -1.2, 0.0))
	await _wait(2.0, func() -> bool: return _player.weapon.data.id == &"shotgun")
	await _wait(0.4)
	_move_goal = Vector2(0.0, -0.5)
	_hunt([a])
	await _wait(4.0, _hunt_done)
	_hunt([])
	_move_goal = Vector2(-0.6, -0.4)
	await _wait(0.6)
	_end_segment()


## 4. Noite na rua residencial (postes acesos, estrelas): repetidora contra dois bots, e o céu.
func _shot_night() -> void:
	var a: Character = _bots[0]
	var b: Character = _bots[1]
	await _prepare(0.75, {
		_player: [Vector3(-42.0, 1.1, -16.0), Vector3(-44.0, 1.1, 2.0)],
		a: [Vector3(-45.0, 1.1, -4.0), Vector3(-42.0, 1.1, -16.0)],
		b: [Vector3(-39.5, 1.1, 0.0), Vector3(-42.0, 1.1, -16.0)],
	}, [a, b], &"repeater")
	_begin_segment()
	_move_goal = Vector2(0.2, -0.6)
	_hunt([a, b])

	await _wait(6.0, _hunt_done)
	_hunt([])
	_move_goal = Vector2.ZERO
	# Fecha olhando o céu da noite por cima dos telhados.
	_aim_rate = 2.5
	_look_at(_player.head.global_position + Vector3(-3.0, 7.0, 12.0))
	await _wait(2.0)
	_end_segment()


# --- Preparação e gravação ---

## Arruma a cena sem gravar: céu (pelo relógio da partida), todos no lugar e virados, bots de
## fora da cena estacionados longe e parados. `places` = {personagem: [onde, para onde olha]}.
func _prepare(progress: float, places: Dictionary, active_bots: Array, weapon_id: StringName = &"") -> void:
	_pilot_on = false
	_release_all()
	_hunt([])
	_aim_rate = 8.0
	var parking: Array[Vector3] = [Vector3(52.0, -0.9, -14.0), Vector3(52.0, -0.9, 14.0),
			Vector3(-56.0, 1.1, 14.0)]
	var characters: Array[Character] = [_player]
	characters.append_array(_bots)
	for i in characters.size():
		var character: Character = characters[i]
		if not character.is_alive:
			_referee.respawn_now(character)
		character.end_spawn_protection()
		character.set_health(character.max_health)
		if places.has(character):
			var spot: Array = places[character]
			_place(character, spot[0], spot[1])
		elif character != _player:
			_place(character, parking[(i - 1) % parking.size()], Vector3.ZERO)
		# Bots parados até a cena começar; o jogador fica ligado (parado, sem comando).
		character.set_physics_process(character == _player)
	if _player.weapon.data.id != WeaponCatalog.DEFAULT_ID:
		_player.weapon.refill()
	if weapon_id != &"":
		_referee.give_weapon(_player, weapon_id)
	_player.apply_look(_player.yaw, 0.0)
	_deathmatch.time_left = MATCH_SECONDS * (1.0 - progress)
	# O céu e o reflexo dele se ajustam aos poucos; a lista de abates antiga some; a arma nova
	# termina de entrar na mão.
	await _frames(45)
	for bot: Character in active_bots:
		bot.set_physics_process(true)
		var brain := bot.controller as BotController
		brain.state = BotController.State.ROAM
		# Na cena os bots brigam ali mesmo: sem fugir pelo trilho (o jogador ia atrás e caía).
		brain.set(&"_rail_cooldown", 1000.0)
	_deathmatch.time_left = MATCH_SECONDS * (1.0 - progress)
	_pilot_on = true


func _begin_segment() -> void:
	_segment_start = _movie_frame
	_recording = true


func _end_segment() -> void:
	_recording = false
	_segments.append([_segment_start, _movie_frame])
	_release_all()


func _on_process_frame() -> void:
	_movie_frame += 1
	if not _recording:
		return
	_clock += 1.0 / FPS
	if _draft and _movie_frame % 3 != 0:
		_saved += 1
		return
	var image: Image = _view.get_texture().get_image()
	var path: String = _out.path_join("frames/f%05d" % _saved)
	if _draft:
		image.save_jpg(path + ".jpg", 0.8)
	else:
		image.save_png(path + ".png")
	_saved += 1


# --- Piloto ---

func _on_physics_frame() -> void:
	if _player == null or not _pilot_on or not _player.is_alive:
		return
	var delta: float = 1.0 / Engine.physics_ticks_per_second
	var goal: Vector3 = Vector3.INF
	if _aim_target != null:
		goal = _aim_target.global_position + Vector3.UP * 1.2
	elif _aim_point != null:
		goal = _aim_point
	if not _hunt_list.is_empty() and (_aim_target == null or _hunt_fallen.has(_aim_target)):
		_aim_target = _pick_target()
	if goal == Vector3.INF and _aim_target != null:
		goal = _aim_target.global_position + Vector3.UP * 1.2
	if goal != Vector3.INF:
		var to: Vector3 = goal - _player.head.global_position
		var want_yaw: float = atan2(-to.x, -to.z)
		var want_pitch: float = atan2(to.y, Vector2(to.x, to.z).length())
		var k: float = 1.0 - exp(-_aim_rate * delta)
		_player.apply_look(_player.yaw + wrapf(want_yaw - _player.yaw, -PI, PI) * k,
				_player.pitch + (want_pitch - _player.pitch) * k)
	_stick = _stick.move_toward(_move_goal if _ground_ahead(_move_goal) else Vector2.ZERO, delta * 5.0)
	_update_stick()
	_set_button(&"fire", _auto_fire and _on_target())
	for action: StringName in _buttons:
		if action != &"fire":
			_set_button(action, _held.get(action, false))
	# Fora do tiroteio a vida volta devagar.
	if _player.health < 60.0:
		_player.set_health(_player.health + 20.0 * delta)


func _keep_alive(health: float, _max_health: float) -> void:
	if health < 30.0 and _player.is_alive:
		_player.set_health(30.0)


func _look_at(point: Vector3) -> void:
	_aim_target = null
	_aim_point = point


## Caça estes bots (lista vazia = para de caçar). Atira sozinho enquanto caça.
func _hunt(targets: Array) -> void:
	_hunt_list.assign(targets)
	_hunt_fallen.clear()
	_aim_target = null
	_aim_point = null
	_auto_fire = not targets.is_empty()
	for target: Character in _hunt_list:
		if not target.died.is_connected(_on_hunted_died.bind(target)):
			target.died.connect(_on_hunted_died.bind(target))


func _on_hunted_died(_killer: Character, target: Character) -> void:
	_hunt_fallen[target] = true


func _hunt_done() -> bool:
	return _hunt_list.all(func(target: Character) -> bool: return _hunt_fallen.has(target))


# O bot da caça mais perto, de preferência um que dá para ver.
func _pick_target() -> Character:
	var best: Character = null
	var best_score: float = INF
	for target: Character in _hunt_list:
		if _hunt_fallen.has(target) or not target.is_alive or target.is_on_rail:
			continue
		var score: float = _player.global_position.distance_to(target.global_position)
		if score > 35.0:
			continue
		if not _can_see(target):
			score += 1000.0
		if score < best_score:
			best_score = score
			best = target
	return best


# Tem chão 1,5 m à frente na direção pedida (senão o jogador para: cair da ilha estraga a cena).
func _ground_ahead(stick: Vector2) -> bool:
	if stick.length() < 0.05 or not _player.is_grounded():
		return true
	var direction: Vector3 = _player.global_basis * Vector3(stick.x, 0.0, stick.y)
	var probe: Vector3 = _player.global_position + direction.normalized() * 1.5 + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 3.0)
	query.exclude = [_player.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _can_see(target: Character) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_player.head.global_position,
			target.global_position + Vector3.UP * 1.2)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target


# A linha da mira passa a menos de 0,5 m do peito do alvo, e nada no meio.
func _on_target() -> bool:
	if _aim_target == null or not _aim_target.is_alive:
		return false
	var eye: Vector3 = _player.head.global_position
	var look: Vector3 = -_player.head.global_basis.z
	var chest: Vector3 = _aim_target.global_position + Vector3.UP * 1.2
	var along: float = (chest - eye).dot(look)
	if along <= 0.0 or (eye + look * along).distance_to(chest) > 0.5:
		return false
	return _can_see(_aim_target)


# O dedão no joystick: aparece onde ele fica parado e o pino vai para a direção pedida.
func _update_stick() -> void:
	if _stick.length() < 0.05:
		if _joystick.is_active():
			_joystick.end()
		return
	var base: Vector2 = _joystick.size * 0.5
	var to_viewport: Transform2D = _joystick.get_global_transform()
	if not _joystick.is_active():
		_joystick.begin(0, to_viewport * base)
	_joystick.drag(to_viewport * (base + _stick * _joystick.radius))


func _set_button(action: StringName, pressed: bool) -> void:
	var button: TouchActionButton = _buttons.get(action)
	if button == null:
		return
	if pressed and button.visible:
		button.press()
	elif not pressed:
		button.release()


## Aperta um botão até `done` ficar verdadeiro (ou acabar o tempo) e solta.
func _press(action: StringName, done: Callable, timeout: float) -> void:
	_held[action] = true
	await _wait(timeout, done)
	_held[action] = false
	await _wait(0.1)


func _release_all() -> void:
	_held.clear()
	_move_goal = Vector2.ZERO
	_stick = Vector2.ZERO
	if _joystick != null:
		_joystick.end()
	for button: TouchActionButton in _buttons.values():
		button.release()


# --- Ajudantes ---

# Põe o personagem em `at`, virado para `facing`.
func _place(character: Character, at: Vector3, facing: Vector3) -> void:
	var to: Vector3 = facing - at
	var yaw: float = atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.01 else 0.0
	character.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
	character.velocity = Vector3.ZERO


## Espera `seconds` do relógio da cena (ou até `until` ficar verdadeiro).
func _wait(seconds: float, until: Callable = Callable()) -> void:
	var end: float = _clock + seconds
	var guard: int = 0
	while _clock < end - 0.001 and guard < 100000:
		if until.is_valid() and until.call():
			return
		await process_frame
		guard += 1
		# Fora da gravação o relógio não anda: conta quadros.
		if not _recording:
			_clock += 1.0 / FPS


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1
