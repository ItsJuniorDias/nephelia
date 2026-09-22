extends SceneTree
## Testes da arena Sky Plaza: ilhas ligadas, pontes, guarda-corpos e bots jogando nela.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_arena.gd
## Código de saída 0 = tudo passou. Esta pasta não deve ir no jogo exportado.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"

var _failures: int = 0
var _level: Node3D
var _player: Character
var _referee: MatchReferee
var _bots: Array[Character] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	(_level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	for node: Node in get_nodes_in_group(&"bots"):
		_bots.append(node as Character)
	# Bots parados (e fora da física) até o teste deles.
	for bot: Character in _bots:
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	await _physics(10)

	await _test_connected_and_spawns()
	await _test_walk_across_bridge()
	await _test_railing_holds()
	await _test_bots_play_the_arena()

	await _physics(70)
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


func _test_connected_and_spawns() -> void:
	var map: RID = _level.get_world_3d().navigation_map
	var start := Vector3(0, 0, 16)
	var unreachable: Array[String] = []
	for goal: Vector3 in [Vector3(-42, 1, 3), Vector3(-50, 1, -2), Vector3(33, -1, 0), Vector3(0, 0, -9)]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
		if path.is_empty() or path[path.size() - 1].distance_to(goal) > 1.2:
			unreachable.append(str(goal))
	var off_mesh: Array[String] = []
	for spawn: Node in get_nodes_in_group(&"spawn_points"):
		var at: Vector3 = (spawn as Node3D).global_position
		if NavigationServer3D.map_get_closest_point(map, at).distance_to(at) > 0.6:
			off_mesh.append(spawn.name)
	var spawns: int = get_nodes_in_group(&"spawn_points").size()
	_check("A1 islands are connected and every spawn point is walkable", unreachable.is_empty()
			and off_mesh.is_empty() and spawns >= 8,
			"unreachable=%s off_mesh=%s spawns=%d" % [unreachable, off_mesh, spawns])


func _test_walk_across_bridge() -> void:
	# Da praça (x = -15) até o jardim oeste andando reto para -X pela ponte.
	_place(_player, Vector3(-15, 0.05, 0), Vector3(-60, 0, 0))
	await _physics(10)
	await physics_frame
	Input.action_press("move_forward")
	await _physics(_seconds(4.5))
	Input.action_release("move_forward")
	await _physics(10)
	var west: Vector3 = _player.global_position
	# E subindo: da ilha leste (mais baixa) até a praça pela ponte leste.
	_place(_player, Vector3(33, -0.95, 0), Vector3(-60, 0, 0))
	await _physics(10)
	await physics_frame
	Input.action_press("move_forward")
	await _physics(_seconds(3.5))
	Input.action_release("move_forward")
	await _physics(10)
	var east: Vector3 = _player.global_position
	_check("A2 player walks across both bridges (up to the garden, up to the plaza)", _player.is_alive
			and west.x < -30.0 and west.y > 0.8 and east.x < 17.0 and east.y > -0.1,
			"west=%s east=%s alive=%s" % [west, east, _player.is_alive])


func _test_railing_holds() -> void:
	# No meio da ponte, andar de lado por 2 s: o guarda-corpo segura.
	_place(_player, Vector3(-24, 0.6, 0), Vector3(-60, 0, 0))
	await _physics(10)
	await physics_frame
	Input.action_press("move_left")
	await _physics(_seconds(2.0))
	Input.action_release("move_left")
	await _physics(20)
	var at: Vector3 = _player.global_position
	_check("A3 bridge railing stops the player from falling off", _player.is_alive and absf(at.z) < 1.8 and at.y > 0.0,
			"pos=%s" % at)


func _test_bots_play_the_arena() -> void:
	# Os 3 bots lutam por 30 s; o jogador assiste de longe, protegido (bots ignoram protegidos).
	_place(_player, Vector3(0, 0.05, 18), Vector3(0, 0, 0))
	_player.respawn(_player.global_transform, 999.0)
	for bot: Character in _bots:
		bot.process_mode = Node.PROCESS_MODE_INHERIT
	var falls: Array[int] = [0]
	var bot_damage: Array[float] = [0.0]
	var on_died := func(_victim: Character, killer: Character) -> void:
		if killer == null:
			falls[0] += 1
	var on_damaged := func(victim: Character, attacker: Character, amount: float) -> void:
		if attacker != null and attacker != _player and victim != _player:
			bot_damage[0] += amount
	_referee.character_died.connect(on_died)
	_referee.character_damaged.connect(on_damaged)
	await _physics(_seconds(30.0))
	_referee.character_died.disconnect(on_died)
	_referee.character_damaged.disconnect(on_damaged)
	_check("A4 bots fight across the arena for 30 s without falling off", falls[0] == 0 and bot_damage[0] > 100.0,
			"falls=%d bot_damage=%.0f" % [falls[0], bot_damage[0]])
