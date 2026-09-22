class_name BotController
extends CharacterController
## Controlador de bot: patrulha a arena, acha inimigos, persegue e atira com o erro de mira
## da sua dificuldade (BotDifficulty).
##
## O bot usa o MESMO comando que o jogador humano (mover, olhar, atirar): não teleporta a mira,
## não atravessa paredes e seus tiros passam pelo mesmo juiz. Estados:
##   ROAM   passeia entre pontos sorteados da navmesh
##   ATTACK vê um inimigo: mira (com erro), atira e anda de lado mantendo distância
##   CHASE  perdeu o inimigo de vista: vai até onde o viu por último

enum State { ROAM, CHASE, ATTACK }

## Percepção 10 vezes por segundo (mais barato que a cada quadro, e parece mais humano).
const THINK_INTERVAL: float = 0.1
## Muito perto, nota o inimigo mesmo fora do campo de visão.
const CLOSE_AWARENESS: float = 4.0
const CHASE_GIVE_UP_TIME: float = 5.0
const ARRIVE_DISTANCE: float = 1.0
const STUCK_CHECK_INTERVAL: float = 1.5
const STUCK_MIN_DISTANCE: float = 0.3
## Distância à frente conferida antes de dar um passo de lado (não cair da ilha).
const EDGE_PROBE: float = 1.2
## Tentativas de sortear um destino alcançável antes de desistir.
const ROAM_PICK_ATTEMPTS: int = 8

@export var difficulty: BotDifficulty
## Só passeia e nunca ataca (testes e, no futuro, tutorial).
@export var passive: bool = false
## Semente dos sorteios (erro de mira, esquiva): mesma semente = mesmo comportamento.
@export var random_seed: int = 1

var state: State = State.ROAM
var target_enemy: Character
var roam_goal: Vector3 = Vector3.ZERO

var _agent: NavigationAgent3D
var _rng := RandomNumberGenerator.new()
var _think_timer: float = 0.0
var _target_visible: bool = false
var _reaction_timer: float = 0.0
var _last_seen_position: Vector3 = Vector3.ZERO
var _chase_timer: float = 0.0
var _aim_noise: Vector2 = Vector2.ZERO
var _aim_noise_goal: Vector2 = Vector2.ZERO
var _aim_noise_timer: float = 0.0
var _strafe_side: float = 1.0
var _strafe_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_check_position: Vector3 = Vector3.ZERO


func setup(for_character: Character) -> void:
	super.setup(for_character)
	character.add_to_group(&"bots")
	if difficulty == null:
		difficulty = load("res://bots/difficulty_medium.tres")
	_rng.seed = random_seed
	_agent = character.get_node("NavigationAgent3D")
	character.respawned.connect(_on_respawned)
	character.hit_received.connect(_on_hit_received)
	_stuck_check_position = character.global_position
	roam_goal = character.global_position


## Anda até `goal` pela navmesh (também usado pelos testes).
func go_to(goal: Vector3) -> void:
	roam_goal = goal
	_agent.target_position = goal


## Sorteia um ponto da navmesh que dê para alcançar andando (ilhas sem ponte não contam).
func pick_roam_goal() -> void:
	if not _navigation_ready():
		# Navmesh ainda não sincronizada (primeiros quadros): fica onde está.
		go_to(character.global_position)
		return
	var map: RID = _navigation_map()
	for attempt in ROAM_PICK_ATTEMPTS:
		var point: Vector3 = NavigationServer3D.map_get_random_point(map, 1, false)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, character.global_position, point, true)
		if not path.is_empty() and path[path.size() - 1].distance_to(point) < ARRIVE_DISTANCE:
			go_to(point)
			return
	go_to(character.global_position)


func get_command(delta: float) -> CharacterCommand:
	command.reset()
	command.yaw = character.yaw
	command.pitch = character.pitch
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_perceive()
	_update_aim_noise(delta)

	match state:
		State.ATTACK:
			_attack(delta)
		State.CHASE:
			_chase(delta)
		_:
			_roam(delta)

	# Fora de combate, aproveita para encher o tambor.
	var weapon: Weapon = character.weapon
	if state != State.ATTACK and weapon != null and weapon.ammo < weapon.magazine_size:
		command.reload = true
	return command


# ---------------------------------------------------------------- percepção

func _perceive() -> void:
	if passive:
		target_enemy = null
		_target_visible = false
		state = State.ROAM if state == State.ATTACK else state
		return

	var best: Character = null
	var best_score: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var other := node as Character
		if other == character or not other.is_alive or other.is_spawn_protected:
			continue
		var distance: float = character.head.global_position.distance_to(_chest_of(other))
		if distance > difficulty.view_distance:
			continue
		if other != target_enemy and distance > CLOSE_AWARENESS and not _in_field_of_view(other):
			continue
		if not _can_see(other):
			continue
		# Prefere continuar no alvo atual (não fica trocando a cada passo).
		var score: float = distance - (5.0 if other == target_enemy else 0.0)
		if score < best_score:
			best = other
			best_score = score

	_target_visible = best != null
	if best != null:
		if best != target_enemy or state != State.ATTACK:
			_reaction_timer = difficulty.reaction_time
		target_enemy = best
		_last_seen_position = best.global_position
		state = State.ATTACK
	elif state == State.ATTACK:
		state = State.CHASE
		_chase_timer = CHASE_GIVE_UP_TIME
		go_to(_last_seen_position)


func _in_field_of_view(other: Character) -> bool:
	var to_other: Vector3 = other.global_position - character.global_position
	to_other.y = 0.0
	var forward: Vector3 = -character.global_basis.z
	return forward.angle_to(to_other) <= deg_to_rad(difficulty.field_of_view_degrees) * 0.5


# Linha de visão do olho do bot até o peito do outro (paredes bloqueiam).
func _can_see(other: Character) -> bool:
	var query := PhysicsRayQueryParameters3D.create(character.head.global_position, _chest_of(other))
	query.exclude = [character.get_rid()]
	var hit: Dictionary = character.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == other


func _chest_of(other: Character) -> Vector3:
	return other.global_position + Vector3.UP * MatchReferee.CHEST_HEIGHT


# ---------------------------------------------------------------- estados

func _attack(delta: float) -> void:
	if target_enemy == null or not target_enemy.is_alive or target_enemy.is_spawn_protected:
		_back_to_roam()
		return
	_reaction_timer -= delta

	# Mira no peito do alvo, com o erro da dificuldade, girando no máximo turn_speed por segundo.
	var to_target: Vector3 = _chest_of(target_enemy) - character.head.global_position
	var desired_yaw: float = atan2(-to_target.x, -to_target.z) + deg_to_rad(_aim_noise.x)
	var desired_pitch: float = atan2(to_target.y, Vector2(to_target.x, to_target.z).length()) + deg_to_rad(_aim_noise.y)
	var turn: float = deg_to_rad(difficulty.turn_speed_degrees) * delta
	command.yaw = rotate_toward(character.yaw, desired_yaw, turn)
	command.pitch = move_toward(character.pitch, desired_pitch, turn)

	var aim_off: float = absf(angle_difference(command.yaw, desired_yaw)) + absf(command.pitch - desired_pitch)
	command.fire = _target_visible and _reaction_timer <= 0.0 \
			and aim_off < deg_to_rad(difficulty.fire_tolerance_degrees)

	# Anda de lado (troca de lado de vez em quando) e ajusta a distância.
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = difficulty.strafe_interval * _rng.randf_range(0.6, 1.4)
		if _rng.randf() < 0.6:
			_strafe_side = -_strafe_side
	var distance: float = to_target.length()
	var forward: float = 0.0
	if distance > difficulty.preferred_distance + 3.0:
		forward = -1.0
	elif distance < difficulty.preferred_distance - 3.0:
		forward = 1.0
	var move := Vector2(_strafe_side, forward).normalized()
	if not _is_safe_step(move):
		_strafe_side = -_strafe_side
		move = Vector2(_strafe_side, forward).normalized()
		if not _is_safe_step(move):
			move = Vector2.ZERO
	command.move = move


func _chase(delta: float) -> void:
	_chase_timer -= delta
	if _chase_timer <= 0.0 or _arrived():
		_back_to_roam()
		return
	_follow_path(delta)


func _roam(delta: float) -> void:
	if _arrived() or _is_stuck(delta):
		pick_roam_goal()
	_follow_path(delta)


func _back_to_roam() -> void:
	state = State.ROAM
	target_enemy = null
	_target_visible = false
	pick_roam_goal()


# ---------------------------------------------------------------- movimento

func _follow_path(delta: float) -> void:
	var to_next: Vector3 = _steering_point() - character.global_position
	to_next.y = 0.0
	command.pitch = move_toward(character.pitch, 0.0, delta)
	if to_next.length() < 0.05:
		return
	var desired_yaw: float = atan2(-to_next.x, -to_next.z)
	command.yaw = rotate_toward(character.yaw, desired_yaw, deg_to_rad(difficulty.turn_speed_degrees) * delta)
	# Direção do caminho no espaço do corpo (dá para andar enquanto ainda está virando).
	var local: Vector3 = character.global_basis.inverse() * to_next.normalized()
	command.move = Vector2(local.x, local.z)


# Próximo ponto do caminho que está de fato à frente. Perto de paredes e rampas a navmesh fica
# "encolhida" sob os pés, e o 1º ponto do caminho pode cair logo acima/abaixo do bot: sem isto
# ele ficaria parado para sempre (distância horizontal zero).
func _steering_point() -> Vector3:
	_agent.get_next_path_position()  # atualiza o caminho e o índice atual
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	var here: Vector3 = character.global_position
	for i in range(_agent.get_current_navigation_path_index(), path.size()):
		if Vector2(path[i].x - here.x, path[i].z - here.z).length() > 0.3:
			return path[i]
	return roam_goal


func _navigation_map() -> RID:
	return character.get_world_3d().navigation_map


# O servidor de navegação só responde depois da primeira sincronização do mapa.
func _navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_navigation_map()) > 0


func _arrived() -> bool:
	var to_goal: Vector3 = roam_goal - character.global_position
	to_goal.y = 0.0
	return to_goal.length() < ARRIVE_DISTANCE or _agent.is_navigation_finished()


# Confere na navmesh se o chão continua um pouco adiante na direção do passo.
func _is_safe_step(move: Vector2) -> bool:
	if move == Vector2.ZERO or not _navigation_ready():
		return true
	var direction: Vector3 = character.global_basis * Vector3(move.x, 0.0, move.y)
	var probe: Vector3 = character.global_position + direction.normalized() * EDGE_PROBE
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(_navigation_map(), probe)
	return Vector2(closest.x - probe.x, closest.z - probe.z).length() < 0.6 and absf(closest.y - probe.y) < 1.0


# Preso numa quina: se quase não saiu do lugar em STUCK_CHECK_INTERVAL, desiste do destino.
func _is_stuck(delta: float) -> bool:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_INTERVAL:
		return false
	_stuck_timer = 0.0
	var moved: float = character.global_position.distance_to(_stuck_check_position)
	_stuck_check_position = character.global_position
	return moved < STUCK_MIN_DISTANCE


# ---------------------------------------------------------------- mira

# O erro de mira "passeia" devagar dentro do limite da dificuldade (não treme a cada quadro).
func _update_aim_noise(delta: float) -> void:
	_aim_noise_timer -= delta
	if _aim_noise_timer <= 0.0:
		_aim_noise_timer = _rng.randf_range(0.3, 0.7)
		var error: float = difficulty.aim_error_degrees
		_aim_noise_goal = Vector2(_rng.randf_range(-error, error), _rng.randf_range(-error, error) * 0.6)
	_aim_noise = _aim_noise.move_toward(_aim_noise_goal, maxf(difficulty.aim_error_degrees, 0.5) * 2.0 * delta)


# ---------------------------------------------------------------- eventos

# Levou tiro: vira para quem atirou (mesmo que estivesse de costas).
func _on_hit_received(result: ShotResult) -> void:
	if passive or result.shooter == null or result.shooter == character or not character.is_alive:
		return
	if state != State.ATTACK or target_enemy == null:
		target_enemy = result.shooter
		_last_seen_position = result.shooter.global_position
		_reaction_timer = difficulty.reaction_time
		state = State.ATTACK
		_think_timer = 0.0


func _on_respawned() -> void:
	_stuck_check_position = character.global_position
	_stuck_timer = 0.0
	_back_to_roam()
