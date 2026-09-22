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

	_test_characters_dressed()
	_test_first_person_sleeves()
	await _test_connected_and_spawns()
	await _test_walk_across_bridge()
	await _test_railing_holds()
	await _test_hook_and_ride_rail()
	await _test_hook_hidden_without_rail()
	await _test_death_on_rail()
	await _test_bot_rides_rail()
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
	for goal: Vector3 in [Vector3(-42, 1, 3), Vector3(-34, 1, -12), Vector3(38, -1, 0), Vector3(0, 0, -9),
			Vector3(0, 0, 19)]:
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


# ---------------------------------------------------------------- trilhos aéreos

func _look_at_point(target: Vector3) -> void:
	var to: Vector3 = target - _player.head.global_position
	_player.apply_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _press(action: StringName, frames: int = 2) -> void:
	await physics_frame
	Input.action_press(action)
	await _physics(frames)
	Input.action_release(action)


func _test_hook_and_ride_rail() -> void:
	var rail: SkylineRail = _level.get_node("Rails/RailSouth")
	var touch: TouchControls = _player.get_node("HumanController/TouchControls")
	var hud: Hud = _player.get_node("HumanController/Hud")
	touch.force_visible = true
	_place(_player, Vector3(0, 0.05, 18), Vector3(10, 0, 18))
	await _physics(10)
	_look_at_point(rail.point_at(rail.closest_offset(Vector3(0, 10, 21))))
	await _physics(3)
	var hint_shown: bool = hud.rail_hint.visible and (touch.get_node("Root/HookButton") as Control).visible
	await _press(&"use_rail")
	await _physics(_seconds(0.6))
	var hanging: bool = _player.is_on_rail and absf(_player.global_position.y - (rail.point_at(rail.closest_offset(_player.global_position)).y - Character.RAIL_HANG)) < 0.1
	# O corpo (visto pelos outros) fica na pose de pendurado, com a mão no trilho.
	var grip_pose: bool = _player.model.is_hanging_pose()
	var start_offset: float = rail.closest_offset(_player.global_position)
	await _physics(_seconds(1.0))
	var travelled: float = absf(rail.closest_offset(_player.global_position) - start_offset)
	# Atirar pendurado funciona.
	var ammo_before: int = _player.weapon.ammo
	await _press(&"fire")
	var fired: bool = _player.weapon.ammo == ammo_before - 1
	_check("R1 HOOK shows near a rail, hooks the player and hangs him below it", hint_shown and hanging and grip_pose,
			"hint=%s hanging=%s grip_pose=%s pos=%s" % [hint_shown, hanging, grip_pose, _player.global_position])
	_check("R2 rides along the rail (> 8 m/s) and can shoot while hanging", travelled > 8.0 and fired,
			"travelled=%.1f m/s fired=%s" % [travelled, fired])
	# Deixa ir até o fim (sobre a ilha leste): sai freado e cai em pé na ilha.
	for i in _seconds(6.0):
		await physics_frame
		if not _player.is_on_rail and _player.is_grounded():
			break
	await _physics(20)
	var at: Vector3 = _player.global_position
	_check("R3 reaching the end of the rail drops the player safely on the island", not _player.is_on_rail
			and _player.is_alive and _player.is_on_floor() and at.x > 28.0 and at.y > -1.5
			and not _player.model.is_hanging_pose(),
			"pos=%s alive=%s on_rail=%s grip_pose=%s" % [at, _player.is_alive, _player.is_on_rail, _player.model.is_hanging_pose()])


func _test_hook_hidden_without_rail() -> void:
	var touch: TouchControls = _player.get_node("HumanController/TouchControls")
	var hud: Hud = _player.get_node("HumanController/Hud")
	_place(_player, Vector3(0, 0.05, 4), Vector3(0, 0, 0))
	_player.apply_look(0.0, deg_to_rad(-30.0))
	await _physics(3)
	await process_frame
	await process_frame
	var hidden: bool = not hud.rail_hint.visible and not (touch.get_node("Root/HookButton") as Control).visible
	await _press(&"use_rail")
	await _physics(5)
	_check("R4 no rail in reach: HOOK hidden and pressing it does nothing", hidden and not _player.is_on_rail,
			"hidden=%s on_rail=%s" % [hidden, _player.is_on_rail])


func _test_death_on_rail() -> void:
	var rail: SkylineRail = _level.get_node("Rails/RailNorth")
	_place(_player, Vector3(0, 0.05, -18), Vector3(10, 0, -18))
	await _physics(10)
	_look_at_point(rail.point_at(rail.closest_offset(Vector3(0, 10, -21))))
	await _press(&"use_rail")
	await _physics(_seconds(0.8))
	var was_on_rail: bool = _player.is_on_rail
	await physics_frame
	_referee.apply_damage(_player, 999.0, null)
	await physics_frame
	var detached: bool = not _player.is_on_rail and not _player.is_alive
	_referee.respawn_now(_player)
	_player.end_spawn_protection()
	await _physics(5)
	_check("R5 dying while hanging drops the rail", was_on_rail and detached and _player.is_alive and not _player.is_on_rail,
			"was_on_rail=%s detached=%s" % [was_on_rail, detached])


func _test_bot_rides_rail() -> void:
	# Bot no jardim com destino longe, no pátio leste: deve pegar o trilho e atravessar.
	var bot: Character = _bots[0]
	var brain := bot.controller as BotController
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	brain.passive = true
	_place(_player, Vector3(0, 0.05, 0), Vector3(0, 0, -10))
	# Escuta os sinais e dá o destino antes de soltar o bot (ele pode engatar já no 1º quadro).
	var rode: Array[bool] = [false]
	var dropped_at: Array[Vector3] = [Vector3.INF]
	var on_attached := func(_rail: SkylineRail) -> void: rode[0] = true
	var on_detached := func() -> void: dropped_at[0] = bot.global_position
	bot.rail_attached.connect(on_attached)
	bot.rail_detached.connect(on_detached)
	_place(bot, Vector3(-36, 1.05, 5), Vector3(0, 1, 5))
	brain.go_to(Vector3(36, -1, 4))
	var arrived_east: bool = false
	for i in _seconds(14.0):
		await physics_frame
		if rode[0] and not bot.is_on_rail and bot.is_grounded() and bot.global_position.x > 26.0:
			arrived_east = true
			break
	bot.rail_attached.disconnect(on_attached)
	bot.rail_detached.disconnect(on_detached)
	brain.passive = false
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	# Pousa no chão do pátio (y = -1), não em cima de um muro (y = 0), onde ficaria preso.
	_check("R6 a bot with a far goal takes the rail across the arena", rode[0] and arrived_east and bot.is_alive
			and bot.global_position.y < -0.5,
			"rode=%s dropped_at=%s arrived_east=%s pos=%s alive=%s" % [rode[0], dropped_at[0], arrived_east,
			bot.global_position, bot.is_alive])


# ---------------------------------------------------------------- aparência

# Peças vestidas no esqueleto do modelo (nomes dos nós que o Wardrobe cria).
func _worn(character: Character) -> PackedStringArray:
	var names := PackedStringArray()
	for node: Node in character.model.skeleton.get_children():
		if node is MeshInstance3D:
			names.append(node.name)
	return names


func _test_characters_dressed() -> void:
	# O jogador veste a roupa (cabeça original, boina); os bots são o corpo original sem roupa,
	# como antes das roupas (pedido do usuário), com a cor deles tingindo o corpo todo.
	var player_parts: PackedStringArray = _worn(_player)
	var bots_plain: bool = true
	var bots_tinted: bool = true
	var details: PackedStringArray = []
	for bot: Character in _bots:
		var parts: PackedStringArray = _worn(bot)
		details.append("%s=%s" % [bot.name, parts])
		bots_plain = bots_plain and "SuperHero_Male" in parts and not "Male_Peasant_Body" in parts \
				and not "Hair" in parts and not "Hat" in parts
		var body_mesh := bot.model.skeleton.get_node("SuperHero_Male") as MeshInstance3D
		var material := body_mesh.get_active_material(0) as BaseMaterial3D
		bots_tinted = bots_tinted and not material.albedo_color.is_equal_approx(Color.WHITE)
	var player_dressed: bool = "Male_Peasant_Body" in player_parts and "Body" in player_parts \
			and "Hat" in player_parts
	_check("C1 the player wears the outfit; bots are the plain original body, tinted with their color",
			player_dressed and bots_plain and bots_tinted and _bots.size() == 3,
			"player=%s %s tinted=%s" % [player_parts, ", ".join(details), bots_tinted])


func _test_first_person_sleeves() -> void:
	# Os braços da 1ª pessoa vestem a roupa do jogador (a manga aparece) e escondem a cabeça.
	var view_model := _player.camera.get_node("ViewModel") as ViewModel
	var parts := PackedStringArray()
	for node: Node in view_model.skeleton.get_children():
		parts.append(node.name)
	var ok: bool = "Male_Peasant_Arms" in parts and "Body" in parts and "HiddenBones" in parts
	_check("C2 first-person arms wear the player's outfit and hide the head", ok, "parts=%s" % [parts])

