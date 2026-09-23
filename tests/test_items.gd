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
	await _test_weapon_pickup()
	await _test_weapon_runs_out()
	await _test_shotgun_pellets()
	await _test_two_handed_grip()
	await _test_first_person_aim()

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


# Atira uma vez e espera o intervalo da arma (como no teste dos controles).
func _fire_once() -> void:
	await physics_frame
	Input.action_press(&"fire")
	await _physics(2)
	Input.action_release(&"fire")
	await _physics(_seconds(_player.weapon.fire_interval) + 2)


func _test_weapon_pickup() -> void:
	# Andar até a repetidora troca a arma do jogador: tambor maior, reserva contada, e as mãos
	# em 1ª pessoa passam a segurar o rifle.
	var item: Pickup = _item("Rifle")
	var hud: Hud = _player.get_node("HumanController/Hud")
	var view_model := _player.camera.get_node_or_null("ViewModel") as ViewModel
	_place(_player, item.global_position + Vector3(3, 0.05, 0), item.global_position)
	await _walk_forward(1.0)
	var weapon: Weapon = _player.weapon
	var rifle: WeaponData = WeaponCatalog.get_weapon(&"repeater")
	_check("I6 walking into the rifle swaps the weapon, the reserve and the hands",
			weapon.data == rifle and weapon.magazine_size == 8 and weapon.reserve == 16
			and not item.is_available and hud.pickup_label.text == "REPEATER"
			and hud.ammo_pips.magazine == 8 and view_model != null and view_model.gun.mesh == rifle.mesh,
			"weapon=%s ammo=%d/%d reserve=%d hud='%s' pips=%d" % [weapon.weapon_name, weapon.ammo,
			weapon.magazine_size, weapon.reserve, hud.pickup_label.text, hud.ammo_pips.magazine])


func _test_weapon_runs_out() -> void:
	# Sem tambor nem reserva, a arma da arena é guardada e o revólver volta sozinho, cheio.
	_place(_player, Vector3(0, 0.05, 0), Vector3(0, 0, -20))
	_referee.give_weapon(_player, &"shotgun")
	var weapon: Weapon = _player.weapon
	var took_shotgun: bool = weapon.data.id == &"shotgun" and weapon.magazine_size == 2
	weapon.reserve = 0
	weapon.ammo = 1
	await _fire_once()
	var empty: bool = weapon.ammo == 0
	await _physics(_seconds(WeaponCatalog.default_weapon().reload_time + 0.4))
	_check("I7 an empty arena weapon is put away and the revolver comes back full",
			took_shotgun and empty and weapon.is_default() and weapon.ammo == 6 and weapon.reserve == -1,
			"took=%s empty=%s now=%s ammo=%d reserve=%d" % [took_shotgun, empty, weapon.weapon_name,
			weapon.ammo, weapon.reserve])


func _test_shotgun_pellets() -> void:
	# Um tiro de espingarda são vários chumbos: de perto machuca bem mais que o revólver.
	# Parado, mas ainda "sólido": por padrão um corpo pausado sai da física (e já estava fora
	# desde o começo do teste), então ele volta por um instante antes de parar de novo.
	var bot: Character = _bots[1]
	bot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	await _physics(2)
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	# Na rua do braço leste, longe dos itens e do monumento do meio da praça.
	_place(_player, Vector3(20, 0.05, -2), Vector3(16, 0, -2))
	_place(bot, Vector3(16, 0.05, -2), Vector3(20, 0, -2))
	await _physics(2)
	bot.set_health(bot.max_health)
	bot.end_spawn_protection()
	_referee.give_weapon(_player, &"shotgun")
	var shots: Array[ShotResult] = []
	var on_fired := func(result: ShotResult) -> void: shots.append(result)
	_player.weapon.fired.connect(on_fired)
	await _fire_once()
	_player.weapon.fired.disconnect(on_fired)
	var result: ShotResult = shots[0] if not shots.is_empty() else null
	_check("I8 one shotgun blast is several pellets and hurts more than the revolver up close",
			result != null and result.pellet_points.size() == 7 and result.damage >= 36.0
			and is_equal_approx(bot.health, bot.max_health - result.damage),
			"shots=%d pellets=%d damage=%.0f bot=%.0f end=%s" % [shots.size(),
			result.pellet_points.size() if result != null else -1,
			result.damage if result != null else -1.0, bot.health,
			result.end_point.snappedf(0.01) if result != null else Vector3.ZERO])
	_player.weapon.refill()


# Erro de cada braço (IK) e se está ligado, no esqueleto de um modelo.
func _grip_state(skeleton: Skeleton3D) -> Dictionary:
	var right := skeleton.get_node(GunMount.RIGHT_ARM_IK) as WeaponGripModifier
	var left := skeleton.get_node(GunMount.LEFT_ARM_IK) as WeaponGripModifier
	return {"active": right.active and left.active, "idle": not right.active and not left.active,
			"miss": maxf(right.miss, left.miss)}


func _test_two_handed_grip() -> void:
	# Armas longas: as duas mãos chegam na arma (corpo de fora e braços da 1ª pessoa).
	# Revólver: nenhuma IK, fica a pose da animação de pistola.
	# O bot precisa estar processando (o suporte da arma anda no _process), mas parado.
	var bot: Character = _bots[1]
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	bot.set_physics_process(false)
	var view_model := _player.camera.get_node("ViewModel") as ViewModel
	var results: PackedStringArray = []
	var ok: bool = true
	for id: StringName in [&"repeater", &"shotgun"]:
		_referee.give_weapon(_player, id)
		_referee.give_weapon(bot, id)
		await _physics(8)
		var state: Dictionary = _grip_state(view_model.skeleton)
		ok = ok and state["active"] and state["miss"] < 0.005
		results.append("%s 1ª pessoa miss=%.3f" % [id, state["miss"]])
		# O corpo visto de fora: mirando de -85° a +85°, no ar e correndo (de frente e de lado). A
		# arma acompanha o peito (WeaponMount), então as mãos não podem ficar longe dela.
		var worst: float = 0.0
		for case: Array in [[0.0, 0.0, -85.0, false], [0.0, 0.0, 0.0, false], [0.0, 0.0, 85.0, false],
				[0.0, 0.0, 60.0, true], [5.0, 0.0, 0.0, false], [5.0, 90.0, 0.0, false]]:
			for i in 30:
				bot.model.update_motion(case[0], deg_to_rad(case[2]), case[3], deg_to_rad(case[1]))
				await process_frame
				if i >= 15:
					state = _grip_state(bot.model.skeleton)
					ok = ok and state["active"]
					worst = maxf(worst, state["miss"])
		ok = ok and worst < 0.01
		results.append("%s de fora pior miss=%.3f" % [id, worst])
	bot.model.update_motion(0.0, 0.0)
	_player.weapon.refill()
	bot.weapon.refill()
	await _physics(3)
	var revolver_idle: bool = _grip_state(bot.model.skeleton)["idle"] and _grip_state(view_model.skeleton)["idle"]
	bot.set_physics_process(true)
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	_check("I9 both hands reach the long guns; the revolver keeps the pistol animation",
			ok and revolver_idle, "%s revolver_idle=%s" % [", ".join(results), revolver_idle])


func _test_first_person_aim() -> void:
	# Em 1ª pessoa o cano da arma longa cruza o centro da tela (onde o tiro vai).
	var view_model := _player.camera.get_node("ViewModel") as ViewModel
	_referee.give_weapon(_player, &"repeater")
	await _physics(10)
	var rifle_error: float = view_model.get_aim_error_degrees()
	_player.weapon.refill()
	await _physics(3)
	_check("I10 in first person the rifle barrel crosses the crosshair",
			rifle_error < 1.5, "error=%.2f°" % rifle_error)

