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
	_test_parts_follow_skeleton()
	await _test_legs_turn_to_walk()
	await _test_connected_and_spawns()
	await _test_walk_across_bridge()
	await _test_railing_holds()
	await _test_hook_and_ride_rail()
	await _test_hook_hidden_without_rail()
	await _test_death_on_rail()
	await _test_visual_effects()
	await _test_sky_cycle()
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
	var sparking: bool = (_player.get_node("CharacterEffects") as CharacterEffects).is_sparking()
	# Atirar pendurado funciona.
	var ammo_before: int = _player.weapon.ammo
	await _press(&"fire")
	var fired: bool = _player.weapon.ammo == ammo_before - 1
	_check("R1 HOOK shows near a rail, hooks the player and hangs him below it", hint_shown and hanging and grip_pose,
			"hint=%s hanging=%s grip_pose=%s pos=%s" % [hint_shown, hanging, grip_pose, _player.global_position])
	_check("R2 rides along the rail (> 8 m/s), can shoot while hanging and the hook throws sparks",
			travelled > 8.0 and fired and sparking,
			"travelled=%.1f m/s fired=%s sparking=%s" % [travelled, fired, sparking])
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


# Efeitos visuais (Vfx) nascem onde aconteceram: um CPUParticles3D criado ligado soltava tudo na
# origem do mapa, escondido dentro do monumento da praça, e nada aparecia (nem as faíscas antigas).
func _test_visual_effects() -> void:
	var effects: ShotEffects = _level.get_node("ShotEffects")
	var spawned: Array[Node] = []
	var collect := func(node: Node) -> void: spawned.append(node)
	effects.child_entered_tree.connect(collect)
	_level.child_entered_tree.connect(collect)

	# Um bot (visto de fora) atira na parede da rua leste: clarão, fumaça, faíscas, poeira e marca.
	var shooter: Character = _bots[0]
	shooter.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(4.0, 0.05, -14.0)))
	_place(_player, Vector3(16, 0.05, 8), Vector3(16, 0, 0))
	await _physics(3)
	var marks_before: int = effects.get_mark_count()
	var origin: Vector3 = shooter.head.global_position
	var wall_shot: ShotResult = _referee.resolve_shot(shooter, shooter.weapon, origin,
			(Vector3(10.0, 1.4, -14.0) - origin).normalized(), false)
	await process_frame
	await process_frame
	var names: PackedStringArray = _names(spawned)
	var dust := _first(spawned, "ImpactDust") as CPUParticles3D
	var dust_gap: float = _particles_center(dust).distance_to(wall_shot.end_point) if dust != null else INF
	_check("V1 a shot at a wall shows muzzle flash and smoke, sparks, dust (at the wall) and a mark",
			wall_shot.hit and wall_shot.victim == null and "MuzzleFlash" in names and "MuzzleSmoke" in names
			and "ImpactSparks" in names and dust_gap < 1.0 and effects.get_mark_count() == marks_before + 1,
			"spawned=%s dust_gap=%.2f marks=%d->%d" % [names, dust_gap, marks_before, effects.get_mark_count()])

	# O jogador (1ª pessoa) acerta um bot: nuvem no corpo, sem marca e sem o clarão de fora.
	var target: Character = _bots[1]
	target.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	target.teleport(Transform3D(Basis.IDENTITY, Vector3(16, 0.05, 3)))
	await _physics(3)
	spawned.clear()
	marks_before = effects.get_mark_count()
	var eye: Vector3 = _player.head.global_position
	var body_shot: ShotResult = _referee.resolve_shot(_player, _player.weapon, eye,
			(target.global_position + Vector3.UP * 1.2 - eye).normalized(), false)
	await process_frame
	await process_frame
	names = _names(spawned)
	target.set_health(target.max_health)
	target.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
	_check("V2 hitting someone makes a small puff on the body (no wall mark, no outside flash in first person)",
			body_shot.victim == target and "BodyPuff" in names and "MuzzleSmoke" in names
			and not "MuzzleFlash" in names and effects.get_mark_count() == marks_before,
			"victim=%s spawned=%s" % [body_shot.victim.name if body_shot.victim else "none", names])

	# Morreu e renasceu: o corpo some numa nuvem onde estava e um anel aparece onde ele nasce.
	var victim: Character = _bots[2]
	victim.teleport(Transform3D(Basis.IDENTITY, Vector3(-16, 0.05, 4)))
	await physics_frame
	var body_at: Vector3 = victim.global_position
	_referee.kill(victim, null)
	await physics_frame
	spawned.clear()
	_referee.respawn_now(victim)
	await process_frame
	var poof := _first(spawned, "DeathPoof") as CPUParticles3D
	var ring := _first(spawned, "SpawnRing") as Node3D
	var poof_gap: float = _particles_center(poof).distance_to(body_at) if poof != null else INF
	var ring_gap: float = ring.global_position.distance_to(victim.global_position) if ring != null else INF
	_check("V3 the dead body vanishes in a puff where it lay and a golden ring marks the respawn",
			poof_gap < 2.0 and ring_gap < 0.5, "poof_gap=%.2f ring_gap=%.2f" % [poof_gap, ring_gap])

	# Cair de uma altura levanta poeira nos pés.
	spawned.clear()
	_player.teleport(Transform3D(Basis.IDENTITY, Vector3(16, 8, -4)))
	# O "está no chão" logo depois do teletransporte ainda é o de antes: espera chegar embaixo.
	for i in _seconds(3.0):
		await physics_frame
		if _player.is_grounded() and _player.global_position.y < 1.0:
			break
	await _physics(2)
	var landing := _first(spawned, "LandingDust") as Node3D
	var landing_gap: float = landing.global_position.distance_to(_player.global_position) if landing != null else INF
	_check("V4 landing from a height raises dust at the feet", landing_gap < 1.0, "gap=%.2f" % landing_gap)

	effects.child_entered_tree.disconnect(collect)
	_level.child_entered_tree.disconnect(collect)


# Da tarde à noite conforme a partida passa: no começo sol forte e sem estrelas; no fim luar
# azulado, estrelas, nebulosa e os postes acesos; "Play Again" volta à tarde. Nuvens giram.
func _test_sky_cycle() -> void:
	var cycle := _level.find_child("SkyCycle", true, false) as SkyCycle
	var deathmatch := _level.get_node("Deathmatch") as Deathmatch
	var clouds := get_first_node_in_group(SkyCycle.CLOUD_GROUP) as Node3D
	var saved_time: float = deathmatch.time_left
	deathmatch.time_left = deathmatch.duration
	await _frames(2)
	var start: Dictionary = cycle.state.duplicate()
	var sun_light: float = cycle.light.light_energy
	var start_lamps: bool = cycle.lamp_lights.any(func(lamp: OmniLight3D) -> bool: return lamp.visible)
	var cloud_turn: float = clouds.rotation.y
	await _physics(30)
	var clouds_moved: bool = absf(clouds.rotation.y - cloud_turn) > 0.001
	deathmatch.time_left = deathmatch.duration * 0.1
	await _frames(2)
	var night: Dictionary = cycle.state.duplicate()
	var moon_light: Color = cycle.light.light_color
	var lamps_on: int = cycle.lamp_lights.filter(func(lamp: OmniLight3D) -> bool: return lamp.visible and lamp.light_energy > 1.0).size()
	var nebula: float = cycle.material.get_shader_parameter(&"nebula_amount")
	deathmatch.time_left = deathmatch.duration
	await _frames(2)
	var back: bool = cycle.state["progress"] < 0.01 and not cycle.lamp_lights.any(func(lamp: OmniLight3D) -> bool: return lamp.visible)
	deathmatch.time_left = saved_time
	_check("V5 the sky goes from afternoon to a starry night with the moon as the match runs; lamps light up",
			start["stars"] == 0.0 and sun_light > 0.9 and not start_lamps and night["stars"] > 0.9
			and night["moon"] > 0.9 and nebula > 0.9 and moon_light.b > moon_light.r
			and lamps_on == cycle.lamp_lights.size() and lamps_on >= 20 and back,
			"sun=%.2f stars %.2f->%.2f moon=%.2f nebula=%.2f moonlight=%s lamps_on=%d/%d back=%s" % [sun_light,
			start["stars"], night["stars"], night["moon"], nebula, moon_light, lamps_on, cycle.lamp_lights.size(), back])
	_check("V6 the clouds drift around the city", clouds_moved, "turn=%.4f" % (clouds.rotation.y - cloud_turn))


# O sinal process_frame vem ANTES dos nós processarem o quadro: espera `count` quadros inteiros.
func _frames(count: int) -> void:
	for i in count + 1:
		await process_frame


func _names(nodes: Array[Node]) -> PackedStringArray:
	var names := PackedStringArray()
	for node: Node in nodes:
		if is_instance_valid(node):
			# Nomes repetidos ganham número no fim ("ImpactDust2"): fica só o nome do efeito.
			names.append(String(node.name).rstrip("0123456789"))
	return names


func _first(nodes: Array[Node], effect_name: String) -> Node:
	for node: Node in nodes:
		if is_instance_valid(node) and String(node.name).rstrip("0123456789") == effect_name:
			return node
	return null


# Centro das partículas vivas, no mundo.
func _particles_center(particles: CPUParticles3D) -> Vector3:
	if particles == null:
		return Vector3.INF
	return particles.global_transform * particles.capture_aabb().get_center()


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
	# Todos vestem a roupa. O jogador tem boina e só o tecido leva a cor; os bots têm a mesma
	# cabeça de antes das roupas (careca, sem chapéu, pele na cor deles: pedido do usuário).
	var player_parts: PackedStringArray = _worn(_player)
	var bots_ok: bool = true
	var details: PackedStringArray = []
	for bot: Character in _bots:
		var parts: PackedStringArray = _worn(bot)
		var skin := (bot.model.skeleton.get_node("Body") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		var skin_tinted: bool = not skin.albedo_color.is_equal_approx(Color.WHITE)
		details.append("%s=%s skin_tinted=%s" % [bot.name, parts, skin_tinted])
		bots_ok = bots_ok and "Male_Peasant_Body" in parts and "Body" in parts and not "Hair" in parts \
				and not "Hat" in parts and skin_tinted
	var player_skin := (_player.model.skeleton.get_node("Body") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	var player_ok: bool = "Male_Peasant_Body" in player_parts and "Hat" in player_parts \
			and player_skin.albedo_color.is_equal_approx(Color.WHITE)
	_check("C1 everyone wears the outfit; bots keep the bald colored head, the player has a cap",
			player_ok and bots_ok and _bots.size() == 3, "player=%s %s" % [player_parts, ", ".join(details)])


func _test_parts_follow_skeleton() -> void:
	# Toda malha do corpo (roupa, cabeça, cabelo, chapéu) está ligada ao esqueleto. Malha criada em
	# código vem com o caminho do esqueleto VAZIO: ficava parada na pose de descanso e, correndo, a
	# cabeça ficava no ar enquanto o corpo balançava (visto pelo usuário no vídeo do bot).
	var loose := PackedStringArray()
	for character: Character in [_player] + _bots:
		for node: Node in character.model.skeleton.get_children():
			var mesh := node as MeshInstance3D
			if mesh != null and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) != character.model.skeleton:
				loose.append("%s/%s" % [character.name, mesh.name])
	_check("C3 head, hair, hat and clothes all follow the skeleton (nothing stuck in the rest pose)",
			loose.is_empty(), "loose=%s" % [loose])


func _test_legs_turn_to_walk() -> void:
	# As pernas tocam a corrida da direção em que ele anda (8 direções da Universal Animation Library
	# Pro) e o tronco continua na pose de mira: as corridas giram e inclinam o quadril, e o
	# TorsoFacingModifier devolve o tronco à pose calibrada com as pernas paradas.
	# O bot fica parado (física desligada), mas com o modelo animando.
	var bot: Character = _bots[0]
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	bot.set_physics_process(false)
	var model: CharacterModel = bot.model
	var torso: TorsoFacingModifier = model.get_torso_modifier()
	for i in 45:
		model.update_motion(0.0, 0.0, false, 0.0)
		await process_frame
	var standing: Quaternion = torso.torso_rotation
	var results: Array[String] = ["parado"]
	var ok: bool = true
	for angle: float in [0.0, 90.0, -90.0, 180.0, 45.0, 135.0, -135.0, -45.0]:
		var worst: float = 0.0
		for i in 60:
			model.update_motion(5.0, 0.0, false, deg_to_rad(angle))
			await process_frame
			if i >= 30:
				worst = maxf(worst, rad_to_deg(standing.angle_to(torso.torso_rotation)))
		var blend: Vector2 = model.get_legs_blend()
		var expected: Vector2 = Vector2(sin(deg_to_rad(angle)), cos(deg_to_rad(angle))) * 5.0
		var hips: float = rad_to_deg(torso.hips_yaw)
		# De lado o quadril gira de verdade (prova de que a corrida de lado está tocando).
		var hips_ok: bool = absf(hips) > 20.0 if absf(angle) == 90.0 else true
		ok = ok and blend.distance_to(expected) < 0.3 and worst < 3.0 and hips_ok
		results.append("%d°: legs=(%.1f, %.1f) hips=%.0f° torso_off<=%.1f°" % [angle, blend.x, blend.y, hips, worst])
	model.update_motion(0.0, 0.0, false, 0.0)
	bot.set_physics_process(true)
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	_check("C4 legs run toward the walk direction (8 directions) while the torso keeps the aim pose", ok,
			", ".join(results))


func _test_first_person_sleeves() -> void:
	# Em 1ª pessoa só os braços (com as mangas da roupa do jogador) aparecem: a gola, o pescoço, o
	# peito, a cabeça e o chapéu ficariam em volta da câmera (faixa marrom na tela, visto no iPhone).
	var view_model := _player.camera.get_node("ViewModel") as ViewModel
	var shown := PackedStringArray()
	var hidden := PackedStringArray()
	for node: Node in view_model.skeleton.get_children():
		if node is MeshInstance3D:
			if (node as MeshInstance3D).visible:
				shown.append(node.name)
			else:
				hidden.append(node.name)
	var ok: bool = shown == PackedStringArray(["Male_Peasant_Arms"]) and "Body" in hidden \
			and "Male_Peasant_Body" in hidden and "Hat" in hidden
	_check("C2 first-person shows only the arms (sleeves); collar, neck, head and hat are hidden", ok,
			"shown=%s hidden=%s" % [shown, hidden])

