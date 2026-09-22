extends SceneTree
## Testes do áudio: canais, som de cada arma, passos conforme o chão, trilho, vento, música,
## cliques e avisos da interface.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_audio.gd
## Código de saída 0 = tudo passou. Sem placa de som (headless) nada toca de verdade, mas os
## tocadores são criados e marcados como tocando: é isso que os testes conferem.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const MENU := "res://ui/main_menu/main_menu.tscn"

var _failures: int = 0
var _level: Node3D
var _player: Character
var _referee: MatchReferee
var _bots: Array[Character] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_buses_and_music_volume()
	await _test_menu_music_and_clicks()

	_level = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	(_level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	for node: Node in get_nodes_in_group(&"bots"):
		var bot := node as Character
		_bots.append(bot)
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	await _physics(10)

	_test_arena_ambience()
	await _test_weapon_sounds()
	await _test_footsteps()
	await _test_rail_sounds()
	await _test_hit_and_hurt_sounds()

	await _physics(5)
	print("RESULT: ", "ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", test_name, "  ", detail)
	else:
		_failures += 1
		print("FAIL  ", test_name, "  ", detail)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _place(character: Character, at: Vector3, look_at: Vector3) -> void:
	var to: Vector3 = look_at - at
	character.teleport(Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.z)), at))


# Tocadores de áudio (de uma vez só) dentro de `parent` tocando `stream`.
func _players_of(parent: Node, stream: AudioStream) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in parent.find_children("*", "", true, false):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node.get(&"stream") == stream:
			found.append(node)
	return found


func _test_buses_and_music_volume() -> void:
	# Canais Music, SFX e UI; o volume da música das opções vale só para o canal da música.
	var buses: Array[String] = []
	for bus: int in AudioServer.bus_count:
		buses.append(AudioServer.get_bus_name(bus))
	var old_music: float = Settings.music_volume
	var old_volume: float = Settings.volume
	Settings.set_option(&"music_volume", 0.25)
	var music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	var master_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))
	Settings.set_option(&"music_volume", old_music)
	Settings.set_option(&"volume", old_volume)
	_check("S1 buses Music, SFX and UI exist; the music option only changes the music bus",
			buses == ["Master", "Music", "SFX", "UI"] and is_equal_approx(music_db, linear_to_db(0.25))
			and is_equal_approx(master_db, linear_to_db(old_volume)),
			"buses=%s music_db=%.1f master_db=%.1f" % [buses, music_db, master_db])


func _test_menu_music_and_clicks() -> void:
	# O menu toca a banda de 1906 no canal da música; botão apertado faz clique no canal da interface.
	var menu: MainMenu = (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var music := menu.get_node_or_null("Music") as AudioStreamPlayer
	var music_ok: bool = music != null and music.playing and music.stream == Sounds.MUSIC_MENU \
			and music.bus == Sounds.MUSIC_BUS
	var clicks: Array[AudioStreamPlayer] = []
	var listen := func(node: Node) -> void:
		if node is AudioStreamPlayer and (node as AudioStreamPlayer).stream == Sounds.UI_CLICK:
			clicks.append(node as AudioStreamPlayer)
	menu.child_entered_tree.connect(listen)
	menu.difficulty_button.pressed.emit()
	await process_frame
	menu.child_entered_tree.disconnect(listen)
	var click_ok: bool = clicks.size() == 1 and clicks[0].bus == Sounds.UI_BUS
	# Volta a dificuldade para a que estava (o botão gira entre as três).
	menu.difficulty_button.pressed.emit()
	menu.difficulty_button.pressed.emit()
	menu.queue_free()
	await process_frame
	_check("S2 main menu plays the 1906 band on the music bus and buttons click on the UI bus",
			music_ok and click_ok, "music=%s click=%s" % [music_ok, click_ok])


func _test_arena_ambience() -> void:
	# Na arena: vento (efeitos) e o ragtime ao piano (música), os dois tocando em loop.
	var ambience := _level.find_child("ArenaAmbience", true, false) as ArenaAmbience
	var ok: bool = ambience != null and ambience.wind.playing and ambience.wind.bus == Sounds.SFX_BUS \
			and ambience.music.playing and ambience.music.stream == Sounds.MUSIC_MATCH \
			and ambience.music.bus == Sounds.MUSIC_BUS and (Sounds.MUSIC_MATCH as AudioStreamOggVorbis).loop \
			and (Sounds.WIND as AudioStreamOggVorbis).loop
	_check("S3 the arena plays wind and the piano rag, both looping", ok,
			"ambience=%s" % [ambience])


func _test_weapon_sounds() -> void:
	# Cada arma tem a sua recarga; o tiro é o sintetizado do projeto, num tom diferente em cada
	# arma (o usuário preferiu ele aos tiros gravados), tocando no canal de efeitos.
	var effects: ShotEffects = _level.get_node("ShotEffects")
	var ids: Array[StringName] = [&"revolver", &"repeater", &"shotgun"]
	var reloads: Array[AudioStream] = []
	var pitches: Array[float] = []
	var played: Array[bool] = []
	_place(_player, Vector3(0, 0.05, 12), Vector3(0, 1.6, -20))
	for id: StringName in ids:
		var data: WeaponData = WeaponCatalog.get_weapon(id)
		reloads.append(data.reload_sound)
		pitches.append(data.shot_pitch)
		_referee.give_weapon(_player, id)
		await physics_frame
		var heard: Array[AudioStreamPlayer3D] = []
		var listen := func(node: Node) -> void:
			if node is AudioStreamPlayer3D and (node as AudioStreamPlayer3D).stream == effects.shot_sound:
				heard.append(node as AudioStreamPlayer3D)
		effects.child_entered_tree.connect(listen)
		Input.action_press(&"fire")
		await _physics(2)
		Input.action_release(&"fire")
		await _physics(2)
		effects.child_entered_tree.disconnect(listen)
		played.append(heard.size() >= 1 and heard[0].bus == Sounds.SFX_BUS)
		await _physics(_seconds(data.fire_interval))
	_player.weapon.refill()
	var synth: bool = effects.shot_sound != null \
			and effects.shot_sound.resource_path.ends_with("revolver_shot_placeholder.wav")
	var reloads_ok: bool = reloads.all(func(r: AudioStream) -> bool: return r != null and reloads.count(r) == 1)
	var pitches_ok: bool = pitches[0] > pitches[1] and pitches[1] > pitches[2]
	_check("S4 the synthesized shot plays for every weapon (lower for bigger guns); each has its own reload",
			synth and reloads_ok and pitches_ok and played == [true, true, true],
			"synth=%s reloads=%s pitches=%s played=%s" % [synth, reloads_ok, pitches, played])


func _test_footsteps() -> void:
	# Andando: uns 3 passos por segundo. Na praça, pedra; no parque do quarteirão oeste, grama.
	var sounds := _player.get_node("CharacterAudio") as CharacterAudio
	# Rua do braço leste, andando para o centro (no meio da praça há um monumento).
	_place(_player, Vector3(21, 0.05, -2), Vector3(0, 0.05, -2))
	await _physics(5)
	var before: int = sounds.steps_played
	Input.action_press(&"move_forward")
	await _physics(_seconds(2.0))
	Input.action_release(&"move_forward")
	var steps: int = sounds.steps_played - before
	var plaza_kind: StringName = sounds.last_step_kind
	var grass_kind: StringName = FloorSurfaces.footstep_kind(self, Vector3(-34, 1.05, 10))
	var park_path_kind: StringName = FloorSurfaces.footstep_kind(self, Vector3(-34, 1.05, 0))
	_check("S5 footsteps: ~3 per second while walking, stone on the plaza and grass in the park",
			steps >= 4 and steps <= 8 and plaza_kind == &"concrete" and grass_kind == &"grass"
			and park_path_kind == &"concrete",
			"steps=%d plaza=%s grass=%s path=%s" % [steps, plaza_kind, grass_kind, park_path_kind])


func _test_rail_sounds() -> void:
	# Engatar faz o "clang" e liga o chiado, que fica mais agudo com a velocidade e para ao soltar.
	var sounds := _player.get_node("CharacterAudio") as CharacterAudio
	var rail := get_nodes_in_group(SkylineRail.GROUP)[0] as SkylineRail
	_place(_player, rail.point_at(4.0) + Vector3.DOWN * Character.RAIL_HANG, rail.point_at(20.0))
	await physics_frame
	_player.attach_to_rail(rail, 4.0)
	await physics_frame
	var hooked: bool = not _players_of(sounds, Sounds.RAIL_HOOK).is_empty() and sounds.is_sliding()
	await _physics(_seconds(1.0))
	var slide := sounds.get_node("RailSlide") as AudioStreamPlayer3D
	var pitch_riding: float = slide.pitch_scale
	_player.detach_from_rail(Vector3.ZERO)
	await physics_frame
	var stopped: bool = not sounds.is_sliding()
	_place(_player, Vector3(0, 0.05, 8), Vector3(0, 0.05, -20))
	await _physics(10)
	_check("S6 rail: hook sound, slide loop rising with speed, silent after letting go",
			hooked and pitch_riding > 0.9 and stopped,
			"hooked=%s pitch=%.2f stopped=%s" % [hooked, pitch_riding, stopped])


func _test_hit_and_hurt_sounds() -> void:
	# Acertar alguém faz o "tic" na interface; levar tiro faz o som de dano no personagem.
	var bot: Character = _bots[0]
	bot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	await _physics(2)
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	_place(_player, Vector3(20, 0.05, -2), Vector3(16, 1.25, -2))
	_place(bot, Vector3(16, 0.05, -2), Vector3(20, 0.05, -2))
	bot.set_health(bot.max_health)
	bot.end_spawn_protection()
	_player.weapon.refill()
	_player.weapon.spread_degrees = 0.0
	await _physics(3)
	# Os sons são curtos (o "tic" some em menos de um décimo de segundo): anota na hora em que
	# cada tocador é criado.
	var hud: Hud = _player.get_node("HumanController/Hud")
	var bot_sounds := bot.get_node("CharacterAudio") as CharacterAudio
	var heard: Array[AudioStream] = []
	var listen := func(node: Node) -> void:
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			heard.append(node.get(&"stream"))
	hud.child_entered_tree.connect(listen)
	bot_sounds.child_entered_tree.connect(listen)
	Input.action_press(&"fire")
	await _physics(2)
	Input.action_release(&"fire")
	await _physics(2)
	hud.child_entered_tree.disconnect(listen)
	bot_sounds.child_entered_tree.disconnect(listen)
	var hit_ok: bool = bot.health < bot.max_health and Sounds.HIT_CONFIRM in heard
	var hurt_ok: bool = Sounds.HURT in heard
	_player.weapon.refill()
	_check("S7 hitting someone ticks on the HUD and the victim makes a hurt sound",
			hit_ok and hurt_ok, "bot=%.0f hit=%s hurt=%s" % [bot.health, hit_ok, hurt_ok])
