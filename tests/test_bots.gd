extends SceneTree
## Testes da IA dos bots: navegação, visão, tiro, tempo de reação, dificuldade e lutas entre bots.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_bots.gd
## Código de saída 0 = tudo passou. Esta pasta não deve ir no jogo exportado.

const EASY: BotDifficulty = preload("res://bots/difficulty_easy.tres")
const MEDIUM: BotDifficulty = preload("res://bots/difficulty_medium.tres")
const HARD: BotDifficulty = preload("res://bots/difficulty_hard.tres")

var _failures: int = 0
var _level: Node3D
var _player: Character
var _referee: MatchReferee
var _bots: Array[Character] = []
var _shots: Array[ShotResult] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _load_level()
	await _test_navigates_around_wall()
	await _test_sees_and_shoots_player()
	await _test_no_shooting_through_walls()
	await _test_reaction_time()
	await _test_turns_when_shot_from_behind()
	await _test_difficulty_accuracy()
	await _test_bots_fight_each_other()
	await _test_roaming_stays_on_island()

	_shots.clear()
	await _physics(70)
	print("RESULT: ", "ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------- helpers

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


func _load_level() -> void:
	_level = (load("res://levels/test_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	(_level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	_referee.shot_resolved.connect(func(result: ShotResult) -> void: _shots.append(result))
	for node: Node in get_nodes_in_group(&"bots"):
		_bots.append(node as Character)
	# Jogador parado e sem controle humano de verdade: só um alvo.
	_player.controller.process_mode = Node.PROCESS_MODE_DISABLED
	await _physics(10)


func _brain(bot: Character) -> BotController:
	return bot.controller as BotController


## Deixa só `active` em jogo. Os outros ficam pausados, fora da física, na ilha pequena
## (inalcançável e longe; abaixo da ilha o juiz os mataria por queda).
func _only(active: Array[Character]) -> void:
	for bot: Character in _bots:
		var keep: bool = active.has(bot)
		bot.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
		bot.process_mode = Node.PROCESS_MODE_INHERIT if keep else Node.PROCESS_MODE_DISABLED
		if not keep:
			bot.global_position = Vector3(38.0 + _bots.find(bot) * 1.5, 4.05, -33.0)
		_revive(bot)
		_brain(bot).passive = false
		_brain(bot).state = BotController.State.ROAM
		_brain(bot).target_enemy = null
	_revive(_player)


func _revive(character: Character) -> void:
	if not character.is_alive:
		_referee.respawn_now(character)
	character.set_health(character.max_health)
	character.end_spawn_protection()
	if character.weapon != null:
		character.weapon.refill()


## Põe o personagem em `at` olhando para `look_at`.
func _place(character: Character, at: Vector3, look_at: Vector3) -> void:
	var to: Vector3 = look_at - at
	character.teleport(Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.z)), at))


func _shots_by(shooter: Character) -> Array[ShotResult]:
	return _shots.filter(func(shot: ShotResult) -> bool: return shot.shooter == shooter)


# ---------------------------------------------------------------- testes

func _test_navigates_around_wall() -> void:
	# Parede em z = -10, de x = -4 a 4. O bot sai de trás dela e precisa contorná-la.
	var bot: Character = _bots[0]
	_only([bot])
	_brain(bot).passive = true
	_place(_player, Vector3(14, 0.05, 12), Vector3(0, 0, 0))
	_place(bot, Vector3(0, 0.05, -13), Vector3(0, 0, -20))
	await _physics(5)
	var goal := Vector3(0, 0, -6)
	_brain(bot).go_to(goal)
	var crossed_through_wall: bool = false
	var last: Vector3 = bot.global_position
	var reached: bool = false
	for i in _seconds(10.0):
		await physics_frame
		var now: Vector3 = bot.global_position
		# Atravessar a linha da parede (z = -10) entre x = -4 e 4 seria atravessar a parede.
		if (last.z < -10.0) != (now.z < -10.0) and absf(now.x) < 4.0:
			crossed_through_wall = true
		last = now
		if Vector2(now.x - goal.x, now.z - goal.z).length() < BotController.ARRIVE_DISTANCE + 0.2:
			reached = true
			break
	_check("B1 walks around the wall to reach the other side", reached and not crossed_through_wall,
			"reached=%s through_wall=%s pos=%s" % [reached, crossed_through_wall, bot.global_position])


func _test_sees_and_shoots_player() -> void:
	var bot: Character = _bots[0]
	_only([bot])
	_brain(bot).difficulty = HARD
	_place(_player, Vector3(0, 0.05, 8), Vector3(0, 0, 0))
	_place(bot, Vector3(8, 0.05, 6), _player.global_position)
	_shots.clear()
	await _physics(_seconds(3.0))
	var fired: int = _shots_by(bot).size()
	_check("B2 sees the player and shoots him", fired >= 2 and _player.health < _player.max_health,
			"shots=%d player_health=%.0f state=%d" % [fired, _player.health, _brain(bot).state])
	_brain(bot).difficulty = MEDIUM


func _test_no_shooting_through_walls() -> void:
	# Jogador escondido atrás da parede; bot do outro lado olhando para ela.
	var bot: Character = _bots[0]
	_only([bot])
	_place(_player, Vector3(0, 0.05, -12), Vector3(0, 0, -20))
	_place(bot, Vector3(0, 0.05, -5), Vector3(0, 0, -12))
	_shots.clear()
	await _physics(_seconds(1.5))
	_check("B3 never shoots at someone behind a wall", _shots_by(bot).is_empty() and _brain(bot).state != BotController.State.ATTACK,
			"shots=%d state=%d" % [_shots_by(bot).size(), _brain(bot).state])


func _test_reaction_time() -> void:
	# Bot fácil (reação 0,65 s): do momento em que vê até o primeiro tiro passa pelo menos isso.
	var bot: Character = _bots[0]
	_only([bot])
	_brain(bot).difficulty = EASY
	_place(_player, Vector3(0, 0.05, 8), Vector3(0, 0, 0))
	# Começa de costas (não vê), depois vira de frente.
	_place(bot, Vector3(6, 0.05, 8), Vector3(12, 0, 8))
	await _physics(10)
	_shots.clear()
	_place(bot, Vector3(6, 0.05, 8), _player.global_position)
	var saw_at: int = -1
	var shot_at: int = -1
	for i in _seconds(3.0):
		await physics_frame
		if saw_at < 0 and _brain(bot).state == BotController.State.ATTACK:
			saw_at = i
		if shot_at < 0 and not _shots_by(bot).is_empty():
			shot_at = i
			break
	var delay: float = float(shot_at - saw_at) / Engine.physics_ticks_per_second
	_check("B4 waits its reaction time before the first shot", saw_at >= 0 and shot_at >= 0 and delay >= EASY.reaction_time - 0.02,
			"saw=%d shot=%d delay=%.2fs (min %.2fs)" % [saw_at, shot_at, delay, EASY.reaction_time])
	_brain(bot).difficulty = MEDIUM


func _test_turns_when_shot_from_behind() -> void:
	var bot: Character = _bots[0]
	_only([bot])
	_place(bot, Vector3(0, 0.05, 2), Vector3(0, 0, -10))
	_place(_player, Vector3(0, 0.05, 10), bot.global_position)
	_player.weapon.spread_degrees = 0.0
	await _physics(5)
	# O jogador atira nas costas do bot (fora do campo de visão dele).
	var eye: Vector3 = _player.head.global_position
	_referee.resolve_shot(_player, _player.weapon, eye, bot.global_position + Vector3.UP * 1.2 - eye, false)
	await _physics(_seconds(1.0))
	var facing: float = rad_to_deg(absf(angle_difference(bot.yaw, atan2(-(_player.global_position - bot.global_position).x,
			-(_player.global_position - bot.global_position).z))))
	_check("B5 turns to face whoever shot it from behind", _brain(bot).target_enemy == _player and facing < 20.0,
			"target=%s facing_error=%.1f°" % [_brain(bot).target_enemy, facing])


func _test_difficulty_accuracy() -> void:
	# Mesmo alvo parado a 12 m: o bot difícil acerta mais que o fácil.
	var bot: Character = _bots[0]
	var hit_rate: Dictionary = {}
	for difficulty: BotDifficulty in [EASY, HARD]:
		_only([bot])
		_brain(bot).difficulty = difficulty
		# Alvo protegido de verdade não serve (bot ignora); o jogador fica vivo com vida infinita.
		_place(_player, Vector3(0, 0.05, 8), Vector3(0, 0, 0))
		_place(bot, Vector3(0, 0.05, -4), _player.global_position)
		_player.max_health = 100000.0
		_player.set_health(_player.max_health)
		_shots.clear()
		await _physics(_seconds(8.0))
		var shots: Array[ShotResult] = _shots_by(bot)
		var hits: int = shots.filter(func(shot: ShotResult) -> bool: return shot.victim == _player).size()
		hit_rate[difficulty.label] = float(hits) / maxf(shots.size(), 1.0)
	_player.max_health = 100.0
	_player.set_health(100.0)
	_brain(bot).difficulty = MEDIUM
	_check("B6 hard bots hit more often than easy bots", hit_rate["Hard"] > hit_rate["Easy"] + 0.15,
			"easy=%.0f%% hard=%.0f%%" % [hit_rate["Easy"] * 100.0, hit_rate["Hard"] * 100.0])


func _test_bots_fight_each_other() -> void:
	# Dois bots frente a frente, jogador longe e fora de vista: eles brigam entre si.
	var a: Character = _bots[0]
	var b: Character = _bots[1]
	_only([a, b])
	_place(_player, Vector3(40, 4.2, -30), Vector3(40, 4, -40))
	_place(a, Vector3(-6, 0.05, 6), Vector3(6, 0, 6))
	_place(b, Vector3(6, 0.05, 6), Vector3(-6, 0, 6))
	var deaths: Array = []
	var on_died := func(victim: Character, killer: Character) -> void: deaths.append([victim, killer])
	_referee.character_died.connect(on_died)
	_shots.clear()
	await _physics(_seconds(15.0))
	_referee.character_died.disconnect(on_died)
	var bot_hits: int = _shots.filter(func(shot: ShotResult) -> bool:
		return shot.victim != null and shot.victim != _player and shot.shooter != _player).size()
	var falls: int = deaths.filter(func(death: Array) -> bool: return death[1] == null).size()
	_check("B7 bots fight each other (and don't fall off while dodging)", bot_hits >= 3 and falls == 0,
			"bot_hits=%d deaths=%d falls=%d" % [bot_hits, deaths.size(), falls])


func _test_roaming_stays_on_island() -> void:
	# Todos os bots passeando (sem brigar) por 25 s: ninguém cai e todos andam.
	_only(_bots)
	_place(_player, Vector3(40, 4.2, -30), Vector3(40, 4, -40))
	var start: Dictionary = {}
	var travelled: Dictionary = {}
	for bot: Character in _bots:
		_brain(bot).passive = true
		start[bot] = bot.global_position
		travelled[bot] = 0.0
	var falls: Array[int] = [0]
	var on_died := func(victim: Character, killer: Character) -> void:
		if killer == null:
			falls[0] += 1
	_referee.character_died.connect(on_died)
	var last: Dictionary = start.duplicate()
	for i in _seconds(25.0):
		await physics_frame
		for bot: Character in _bots:
			travelled[bot] += Vector2(bot.global_position.x - last[bot].x, bot.global_position.z - last[bot].z).length()
			last[bot] = bot.global_position
	_referee.character_died.disconnect(on_died)
	var min_travel: float = INF
	for bot: Character in _bots:
		min_travel = minf(min_travel, travelled[bot])
		_brain(bot).passive = false
	_check("B8 roaming bots keep moving and never fall off", falls[0] == 0 and min_travel > 15.0,
			"falls=%d min_travel=%.1f m" % [falls[0], min_travel])
