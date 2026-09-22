extends SceneTree
## Testes dos itens da arena (frascos de vida, energia, armas) na Sky Plaza.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_items.gd
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

	await _test_health_pickup()
	await _test_full_health_keeps_pickup()
	await _test_pickup_respawns()
	await _test_bot_fetches_health()
	await _test_restart_restores_pickups()

	await _physics(10)
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


func _item(item_name: String) -> Pickup:
	return _level.get_node("Items/" + item_name) as Pickup


# Anda para frente por `seconds` segundos.
func _walk_forward(seconds: float) -> void:
	await physics_frame
	Input.action_press(&"move_forward")
	await _physics(_seconds(seconds))
	Input.action_release(&"move_forward")
	await _physics(5)


func _test_health_pickup() -> void:
	# Machucado, anda até o frasco da praça: ganha 50 de vida, o frasco some e o HUD avisa.
	var item: Pickup = _item("Health1")
	var hud: Hud = _player.get_node("HumanController/Hud")
	_place(_player, item.global_position + Vector3(0, 0.05, -3), item.global_position)
	_player.set_health(40.0)
	await _walk_forward(1.0)
	_check("I1 a hurt player walking into a health bottle gets +50 HP and the bottle disappears",
			is_equal_approx(_player.health, 90.0) and not item.is_available and hud.pickup_label.visible
			and hud.pickup_label.text == "+50 HP",
			"health=%.0f available=%s hud=%s '%s'" % [_player.health, item.is_available,
			hud.pickup_label.visible, hud.pickup_label.text])


func _test_full_health_keeps_pickup() -> void:
	# Com vida cheia o frasco fica lá para quem precisar.
	var item: Pickup = _item("Health2")
	_player.set_health(_player.max_health)
	_place(_player, item.global_position + Vector3(0, 0.05, 3), item.global_position)
	await _walk_forward(1.0)
	_check("I2 at full health the bottle stays", item.is_available and is_equal_approx(_player.health, 100.0),
			"available=%s health=%.0f" % [item.is_available, _player.health])


func _test_pickup_respawns() -> void:
	# O frasco pego no I1 volta depois do tempo dele (encurtado para o teste).
	var item: Pickup = _item("Health1")
	_place(_player, Vector3(0, 0.05, 14), Vector3(0, 0, 20))
	item.respawn_time = 1.0
	item.take(null)
	var gone: bool = not item.is_available
	await _physics(_seconds(1.3))
	_check("I3 a taken bottle comes back after its respawn time", gone and item.is_available,
			"gone=%s back=%s" % [gone, item.is_available])
	item.respawn_time = 20.0


func _test_bot_fetches_health() -> void:
	# Bot machucado (e sem ninguém para atacar) vai buscar o frasco mais perto.
	var bot: Character = _bots[0]
	var brain := bot.controller as BotController
	brain.passive = true
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	_place(bot, Vector3(-10, 0.05, -12), Vector3(0, 0, -12))
	bot.set_health(30.0)
	var picked: Array[bool] = [false]
	var on_picked := func(_pickup: Pickup) -> void: picked[0] = true
	bot.picked_up.connect(on_picked)
	for i in _seconds(12.0):
		await physics_frame
		if picked[0]:
			break
	bot.picked_up.disconnect(on_picked)
	_check("I4 a hurt bot walks to the nearest bottle and heals", picked[0] and is_equal_approx(bot.health, 80.0),
			"picked=%s health=%.0f pos=%s" % [picked[0], bot.health, bot.global_position])
	brain.passive = false
	bot.process_mode = Node.PROCESS_MODE_DISABLED


func _test_restart_restores_pickups() -> void:
	var taken_before: int = 0
	for node: Node in get_nodes_in_group(Pickup.GROUP):
		if not (node as Pickup).is_available:
			taken_before += 1
	(_level.get_node("Deathmatch") as Deathmatch).restart()
	await _physics(2)
	var all_back: bool = true
	for node: Node in get_nodes_in_group(Pickup.GROUP):
		all_back = all_back and (node as Pickup).is_available
	_check("I5 restarting the match brings every item back", taken_before > 0 and all_back,
			"taken_before=%d all_back=%s" % [taken_before, all_back])
