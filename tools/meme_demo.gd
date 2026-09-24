extends SceneTree
## Ferramenta: vídeo curto com os sons de meme (MemeSounds) acontecendo de verdade na partida, um
## momento por vez, com legenda (em português: é material para o usuário aprovar, não texto do jogo).
##   Godot --path . -s res://tools/meme_demo.gd --always-on-top --write-movie <pasta>/demo.avi --fixed-fps 30
##   ffmpeg -i <pasta>/demo.avi -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k <pasta>/demo.mp4
## A música fica muda para os sons aparecerem.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"

var _level: Node3D
var _player: Character
var _referee: MatchReferee
var _deathmatch: Deathmatch
var _bots: Array[Character] = []
var _memes: MemeSounds
var _caption: Label


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	Settings.funny_sounds = true
	_level = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	_deathmatch = _level.get_node("Deathmatch")
	_deathmatch.time_left = 240.0
	_build_caption()
	for node: Node in get_nodes_in_group(&"bots"):
		var bot := node as Character
		(bot.controller as BotController).passive = true
		bot.set_physics_process(false)
		_bots.append(bot)
	_place(_player, Vector3(0.0, 0.1, 16.0), Vector3(0.0, 0.1, 30.0))
	await _frames(5)
	_memes = _level.find_child("MemeSounds", true, false)
	_memes._rng.seed = 7

	_say("Começo da partida: gongo")
	await _seconds(3.0)

	_say("Bot cai da ilha sozinho: apito no ar + risada da plateia")
	var faller: Character = _bots[0]
	# Longe da "estação" do trilho e sem poder engatar (senão ele pega o trilho em vez de cair).
	(faller.controller as BotController).set(&"_rail_cooldown", 1000.0)
	_place(faller, Vector3(-8.0, 1.0, 25.0), Vector3(-8.0, 1.0, 16.0))
	faller.set_physics_process(true)
	_look_at(faller.global_position + Vector3.UP * 1.2)
	for i in 30:
		await process_frame
		_look_at(faller.global_position + Vector3.UP * 1.2)
	await _seconds(3.5)
	faller.set_physics_process(false)

	_say("Tiro na cabeça que elimina: BOOM")
	_place(_player, Vector3(0.0, 0.1, 16.0), Vector3(0.0, 0.1, 10.0))
	var target: Character = _bots[1]
	_referee.respawn_now(target)
	target.end_spawn_protection()
	_place(target, Vector3(0.0, 0.1, 10.0), Vector3(0.0, 0.1, 16.0))
	target.set_health(10.0)
	await _headshot(target)
	await _seconds(2.5)

	_say("Tiro na cabeça sem matar: bonk")
	var tough: Character = _bots[2]
	_referee.respawn_now(tough)
	tough.end_spawn_protection()
	_place(tough, Vector3(1.5, 0.1, 10.0), Vector3(0.0, 0.1, 16.0))
	await _headshot(tough)
	await _seconds(1.5)

	_say("3 abates seguidos: buzina")
	tough.set_health(10.0)
	await _headshot(tough)
	await _seconds(0.6)
	var third: Character = _bots[0]
	_referee.respawn_now(third)
	third.end_spawn_protection()
	_place(third, Vector3(-1.5, 0.1, 10.0), Vector3(0.0, 0.1, 16.0))
	third.set_health(10.0)
	await _headshot(third, false)
	await _seconds(2.5)

	_say("Pegou uma arma: ka-ching")
	_place(_player, Vector3(-12.0, 0.1, 6.0), Vector3(-20.0, 0.1, 6.0))
	for i in 40:
		Input.action_press(&"move_forward")
		await physics_frame
	Input.action_release(&"move_forward")
	await _seconds(2.0)

	_say("Recarregar com a arma cheia: bipe de erro")
	await _tap(&"reload")
	await _seconds(1.5)

	_say("Errou o tambor inteiro: grilos")
	_player.weapon.refill()
	await _seconds(0.5)
	_player.apply_look(_player.yaw, deg_to_rad(60.0))
	Input.action_press(&"fire")
	await _seconds(2.4)
	Input.action_release(&"fire")
	await _seconds(3.0)

	_say("Morreu depois de 3 abates seguidos: arranhão de disco + imagem congelada")
	_player.apply_look(_player.yaw, 0.0)
	_referee.kill(_player, null)
	await _seconds(3.5)

	_say("Morreu 3 vezes seguidas: marcha fúnebre")
	for i in 2:
		_referee.respawn_now(_player)
		_player.end_spawn_protection()
		await _seconds(0.8)
		_referee.kill(_player, null)
	await _seconds(6.0)

	_say("Faltam 30 segundos: dun dun DUNNN")
	_referee.respawn_now(_player)
	_player.end_spawn_protection()
	_deathmatch.time_left = 30.5
	await _seconds(4.0)

	_say("Terminou em 1º lugar: fanfarra de kazoo")
	_deathmatch.finish()
	await _seconds(3.5)
	quit()


# Mira na cabeça e dá um tiro de verdade (o juiz resolve). `wait` espera o tiro sair.
func _headshot(target: Character, wait: bool = true) -> void:
	for i in 10:
		_look_at(target.head.global_position)
		await physics_frame
	await _tap(&"fire")
	if wait:
		await _seconds(0.3)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _look_at(point: Vector3) -> void:
	var to: Vector3 = point - _player.head.global_position
	_player.apply_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _place(character: Character, at: Vector3, facing: Vector3) -> void:
	var to: Vector3 = facing - at
	character.teleport(Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.z)), at))
	character.velocity = Vector3.ZERO


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 90.0
	layer.add_child(panel)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_caption)


func _say(text: String) -> void:
	_caption.text = text
	var panel := _caption.get_parent() as Control
	panel.reset_size()
	panel.position.x = (root.get_visible_rect().size.x - panel.size.x) * 0.5
	print("DEMO ", text)


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * 30.0))


func _frames(count: int) -> void:
	for i in count:
		await process_frame
