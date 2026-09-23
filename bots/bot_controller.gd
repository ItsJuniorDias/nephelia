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
## Fora de briga, machucado, vai buscar o frasco de vida mais perto.

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
## Só pega trilho para destinos a pelo menos esta distância.
const RAIL_MIN_TRIP: float = 22.0
## Depois de soltar de um trilho, espera este tempo antes de pegar outro.
const RAIL_COOLDOWN: float = 6.0
## Só pega o trilho se ele chega a esta fração da distância que falta até o destino.
const RAIL_WORTH_FRACTION: float = 0.4
## Distância entre os pontos conferidos ao longo do trilho.
const RAIL_SAMPLE_STEP: float = 4.0
## Só vai atrás de itens até esta distância (em linha reta).
const ITEM_SEARCH_DISTANCE: float = 35.0
## Arma vale menos que vida: o bot só desvia do caminho por uma que esteja aqui do lado.
const WEAPON_SEARCH_DISTANCE: float = 16.0
## Busca frasco de vida quando a vida cai abaixo desta fração do máximo.
const WANT_HEALTH_BELOW: float = 0.6

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
var _rail_cooldown: float = 0.0
var _rail_goal_distance: float = INF
var _was_grounded: bool = true
## Item que está indo buscar (null = nenhum).
var _item_goal: Pickup


func setup(for_character: Character) -> void:
	super.setup(for_character)
	character.add_to_group(&"bots")
	if difficulty == null:
		difficulty = load("res://bots/difficulty_medium.tres")
	_rng.seed = random_seed
	_agent = character.get_node("NavigationAgent3D")
	character.respawned.connect(_on_respawned)
	character.hit_received.connect(_on_hit_received)
	character.rail_attached.connect(func(_rail: SkylineRail) -> void: _rail_goal_distance = INF)
	character.rail_detached.connect(func() -> void: _rail_cooldown = RAIL_COOLDOWN)
	rail_hook_cone = PI
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
	# O alvo saiu da partida (multiplayer): esquece ele.
	if target_enemy != null and not is_instance_valid(target_enemy):
		_back_to_roam()
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_perceive()
		_think_items()
	_update_aim_noise(delta)

	_rail_cooldown = maxf(_rail_cooldown - delta, 0.0)
	# Pousou depois de estar no ar (fim do trilho, queda): o caminho calculado lá de cima pode
	# começar em outra ilha. Pede um caminho novo a partir de onde está agora.
	var grounded: bool = character.is_on_floor()
	if grounded and not _was_grounded:
		_agent.target_position = roam_goal
	_was_grounded = grounded
	match state:
		State.ATTACK:
			_attack(delta)
		State.CHASE:
			_chase(delta)
		_:
			_roam(delta)
	if character.is_on_rail:
		_steer_on_rail(delta)
	elif not character.is_grounded():
		# No ar (soltou do trilho): não se guia; cai onde _safe_to_drop previu.
		command.move = Vector2.ZERO

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
	if character.is_on_rail:
		return
	if _try_take_rail(delta):
		return
	if _arrived() or _is_stuck(delta):
		_item_goal = null
		pick_roam_goal()
	_follow_path(delta)


func _back_to_roam() -> void:
	state = State.ROAM
	target_enemy = null
	_target_visible = false
	# O próximo "pensamento" decide de novo se vale buscar um item.
	_item_goal = null
	pick_roam_goal()


# ---------------------------------------------------------------- movimento

func _follow_path(delta: float) -> void:
	# Pendurado no trilho quem manda é _steer_on_rail (e o caminho só é calculado no chão).
	if character.is_on_rail:
		return
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


# ---------------------------------------------------------------- trilhos

# Pega o trilho quando o destino é longe e o trilho leva bem mais perto dele. O personagem
# desliza para o lado em que está virado: se o bom sentido é o contrário, o bot primeiro vira.
# Devolve true enquanto está tratando do trilho (engatando ou virando para ele).
func _try_take_rail(delta: float) -> bool:
	if _rail_cooldown > 0.0:
		return false
	var to_goal: Vector3 = roam_goal - character.global_position
	to_goal.y = 0.0
	var distance: float = to_goal.length()
	if distance < RAIL_MIN_TRIP:
		return false
	var hook: Dictionary = character.find_hookable_rail(rail_hook_cone)
	if hook.is_empty():
		return false
	var rail: SkylineRail = hook["rail"]
	var offset: float = hook["offset"]
	var best_direction: float = 0.0
	var best_distance: float = distance * RAIL_WORTH_FRACTION
	for direction: float in [1.0, -1.0]:
		var reach: float = _rail_closest_approach(rail, offset, direction)
		if reach < best_distance:
			best_distance = reach
			best_direction = direction
	if best_direction == 0.0:
		return false
	var travel: Vector3 = rail.tangent_at(offset) * best_direction
	travel.y = 0.0
	if travel.dot(-character.global_basis.z) > 0.2:
		command.use_rail = true
	else:
		command.yaw = rotate_toward(character.yaw, atan2(-travel.x, -travel.z),
				deg_to_rad(difficulty.turn_speed_degrees) * delta)
	return true


# Quanto o trilho chega perto do destino, andando dele a partir de `offset` no sentido `direction`.
func _rail_closest_approach(rail: SkylineRail, offset: float, direction: float) -> float:
	var closest: float = INF
	var length: float = rail.get_length()
	var along: float = offset
	while along >= 0.0 and along <= length:
		var point: Vector3 = rail.point_at(along)
		closest = minf(closest, Vector2(point.x - roam_goal.x, point.z - roam_goal.z).length())
		along += direction * RAIL_SAMPLE_STEP
	return closest


# Pendurado: acelera, olha para onde vai (se não estiver mirando) e solta perto do destino,
# ou quando começa a se afastar dele, mas só se houver chão embaixo.
func _steer_on_rail(delta: float) -> void:
	command.move = Vector2(0.0, -1.0)
	# Sendo puxado até o trilho: pode se afastar um pouco do destino, ainda não é hora de soltar.
	if character.is_rail_pulling:
		return
	if state != State.ATTACK and character.velocity.length() > 0.5:
		var travel: Vector3 = character.velocity
		command.yaw = rotate_toward(character.yaw, atan2(-travel.x, -travel.z),
				deg_to_rad(difficulty.turn_speed_degrees) * delta)
	var to_goal: Vector3 = roam_goal - character.global_position
	to_goal.y = 0.0
	var distance: float = to_goal.length()
	var getting_farther: bool = distance > _rail_goal_distance + 0.05
	_rail_goal_distance = minf(_rail_goal_distance, distance)
	if (distance < 8.0 or getting_farther) and _safe_to_drop():
		command.use_rail = true


# Solta só se o ponto onde vai CAIR (seguindo a velocidade atual) tem chão da arena.
func _safe_to_drop() -> bool:
	var from: Vector3 = character.global_position
	var below: Dictionary = _ray_down(from, 15.0)
	if below.is_empty():
		return false
	var height: float = from.y - (below["position"] as Vector3).y
	var fall_time: float = sqrt(2.0 * maxf(height, 0.0) / 9.8)
	# Sem se guiar no ar, o deslize para os lados vai freando (air_acceleration) até parar.
	var flat := Vector3(character.velocity.x, 0.0, character.velocity.z)
	var speed: float = flat.length()
	var braking: float = maxf(character.air_acceleration, 0.01)
	var t: float = minf(fall_time, speed / braking)
	var landing: Vector3 = from + flat.normalized() * (speed * t - 0.5 * braking * t * t)
	var ground: Dictionary = _ray_down(landing + Vector3.UP * 3.0, 20.0)
	if ground.is_empty():
		return false
	# E o chão de pouso precisa ser andável (navmesh), não um telhado ou a borda da ilha...
	var map: RID = _navigation_map()
	var point: Vector3 = ground["position"]
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
	if closest.distance_to(point) >= 1.0:
		return false
	# ...e ligado por terra ao destino (o topo de um muro também tem navmesh, mas é uma "ilha").
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, closest, roam_goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(roam_goal) < ARRIVE_DISTANCE


func _ray_down(from: Vector3, length: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * length)
	query.exclude = [character.get_rid()]
	return character.get_world_3d().direct_space_state.intersect_ray(query)


# ---------------------------------------------------------------- itens

# Sem briga e precisando de algo: vai buscar o item alcançável (a pé) mais perto.
func _think_items() -> void:
	if _item_goal != null:
		# Alguém pegou antes, ou já não precisa: volta a passear.
		if not _item_goal.is_available or not _wants(_item_goal):
			_item_goal = null
			pick_roam_goal()
		return
	if state == State.ATTACK or character.is_on_rail or not character.is_alive:
		return
	var candidates: Array[Pickup] = []
	for node: Node in get_tree().get_nodes_in_group(Pickup.GROUP):
		var pickup := node as Pickup
		if pickup.is_available and _wants(pickup) \
				and character.global_position.distance_to(pickup.global_position) < _search_distance(pickup):
			candidates.append(pickup)
	if candidates.is_empty():
		return
	# Machucado, vida antes de arma: só depois procura uma arma melhor. Entre iguais, a mais perto.
	var here: Vector3 = character.global_position
	candidates.sort_custom(func(a: Pickup, b: Pickup) -> bool:
		if _item_priority(a) != _item_priority(b):
			return _item_priority(a) < _item_priority(b)
		return here.distance_squared_to(a.global_position) < here.distance_squared_to(b.global_position))
	for pickup: Pickup in candidates:
		if _reachable(pickup.global_position):
			_item_goal = pickup
			state = State.ROAM
			go_to(pickup.global_position)
			return


func _search_distance(pickup: Pickup) -> float:
	return ITEM_SEARCH_DISTANCE if pickup.kind == Pickup.Kind.HEALTH else WEAPON_SEARCH_DISTANCE


# Ordem de interesse: 0 = vida (urgente), 1 = arma.
func _item_priority(pickup: Pickup) -> int:
	return 0 if pickup.kind == Pickup.Kind.HEALTH else 1


func _wants(pickup: Pickup) -> bool:
	match pickup.kind:
		Pickup.Kind.HEALTH:
			return character.health < character.max_health * WANT_HEALTH_BELOW
		Pickup.Kind.RIFLE, Pickup.Kind.SHOTGUN:
			# Troca o revólver por qualquer arma da arena, e volta nela quando a munição baixa.
			var weapon: Weapon = character.weapon
			return weapon != null and (weapon.is_default() or not weapon.is_full())
	return false


func _reachable(point: Vector3) -> bool:
	if not _navigation_ready():
		return false
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_navigation_map(), character.global_position, point, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(point) < 1.5


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
