class_name MatchReferee
extends Node
## Juiz da partida: decide se cada tiro acertou e em quem, quem pega cada item, vida e morte.
##
## Hoje roda no próprio aparelho. No multiplayer só o servidor terá o juiz, e é isso que
## impede trapaça: o jogador só diz "atirei nesta direção"; quem decide o acerto é o juiz.

signal shot_resolved(result: ShotResult)
signal character_damaged(victim: Character, attacker: Character, amount: float)
## `killer` é null quando foi queda ou outro acidente.
signal character_died(victim: Character, killer: Character)
signal character_respawned(character: Character)
signal item_picked(character: Character, pickup: Pickup)

const GROUP: StringName = &"match_referee"
## Depois de levar dano, a queda conta como abate de quem atacou por este tempo (empurrão vale).
const FALL_CREDIT_TIME: float = 3.0
## Altura, a partir dos pés, do ponto que a mira assistida procura no alvo (peito).
const CHEST_HEIGHT: float = 1.2

@export_group("Vida e respawn")
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_delay: float = 3.0
## Depois de nascer, o personagem não leva dano por este tempo (ou até atirar).
@export_range(0.0, 10.0, 0.1, "suffix:s") var spawn_protection_time: float = 2.0
## Abaixo desta altura o personagem caiu da arena e morre.
@export var fall_limit_y: float = -30.0

@export_group("Mira assistida")
## Ângulo máximo entre a mira e o alvo para a ajuda agir.
@export_range(0.0, 20.0, 0.5, "suffix:°") var assist_max_angle: float = 8.0
## Distância máxima entre a linha da mira e o alvo. Evita ajuda exagerada em alvos longe.
@export_range(0.0, 5.0, 0.1, "suffix:m") var assist_max_offset: float = 1.0

var _rng := RandomNumberGenerator.new()
## Quem está esperando para renascer, e quanto tempo falta.
var _respawn_timers: Dictionary[Character, float] = {}
## Último a machucar cada personagem, e quanto tempo o crédito ainda vale (quedas).
var _last_attackers: Dictionary[Character, Array] = {}


## Acha o juiz da cena atual (ou null se não houver).
static func find(from: Node) -> MatchReferee:
	return from.get_tree().get_first_node_in_group(GROUP) as MatchReferee


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	for character: Character in _last_attackers.keys():
		var credit: Array = _last_attackers[character]
		credit[1] -= delta
		if credit[1] <= 0.0:
			_last_attackers.erase(character)
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.is_alive and character.global_position.y < fall_limit_y:
			# Caiu: se alguém acabou de acertar ou empurrar, o abate é dele.
			kill(character, _recent_attacker(character))
	for character: Character in _respawn_timers.keys():
		_respawn_timers[character] -= delta
		if _respawn_timers[character] <= 0.0:
			respawn_now(character)


## Tira vida de `victim`. Devolve o dano aplicado (0 se já morto ou protegido).
func apply_damage(victim: Character, amount: float, attacker: Character) -> float:
	if not victim.is_alive or victim.is_spawn_protected or amount <= 0.0:
		return 0.0
	var applied: float = minf(amount, victim.health)
	if attacker != null and attacker != victim:
		_last_attackers[victim] = [attacker, FALL_CREDIT_TIME]
	victim.set_health(victim.health - amount)
	character_damaged.emit(victim, attacker, applied)
	if victim.health <= 0.0:
		kill(victim, attacker)
	return applied


## Devolve vida, sem passar do máximo.
func heal(character: Character, amount: float) -> void:
	if character.is_alive and amount > 0.0:
		character.set_health(character.health + amount)


## Dá uma arma da arena ao personagem (tambor e reserva cheios). Devolve se valeu: quem já está
## com ela cheia deixa o item lá para os outros.
func give_weapon(character: Character, weapon_id: StringName) -> bool:
	var weapon: Weapon = character.weapon
	var data: WeaponData = WeaponCatalog.get_weapon(weapon_id)
	if weapon == null or data == null:
		return false
	if weapon.data == data and weapon.is_full():
		return false
	weapon.equip(data)
	return true


## `character` encostou em `pickup`: pega se o item está lá e se ele precisa (vida cheia não
## gasta o frasco). Devolve se pegou.
func try_pickup(character: Character, pickup: Pickup) -> bool:
	if not character.is_alive or not pickup.is_available:
		return false
	match pickup.kind:
		Pickup.Kind.HEALTH:
			if character.health >= character.max_health:
				return false
			heal(character, pickup.amount)
		Pickup.Kind.RIFLE, Pickup.Kind.SHOTGUN:
			if not give_weapon(character, Pickup.weapon_id_of(pickup.kind)):
				return false
		_:
			return false
	pickup.take(character)
	character.receive_pickup(pickup)
	item_picked.emit(character, pickup)
	return true


## Mata `victim` e agenda o respawn. `killer` null = queda ou acidente.
func kill(victim: Character, killer: Character) -> void:
	if not victim.is_alive:
		return
	victim.die(killer)
	_respawn_timers[victim] = respawn_delay
	character_died.emit(victim, killer)


## Faz renascer já, no ponto mais seguro (usado pelo cronômetro e pelos testes).
func respawn_now(character: Character) -> void:
	_respawn_timers.erase(character)
	# Vida nova: o crédito da queda para quem atacou antes não vale mais.
	_last_attackers.erase(character)
	character.respawn(pick_spawn_point(character), spawn_protection_time)
	character_respawned.emit(character)


## Ponto de nascimento (grupo "spawn_points") mais longe dos outros personagens vivos.
func pick_spawn_point(for_character: Character) -> Transform3D:
	var best: Transform3D = for_character.global_transform
	var best_distance: float = -1.0
	for point: Node in get_tree().get_nodes_in_group(&"spawn_points"):
		var spawn := point as Node3D
		var nearest_enemy: float = INF
		for node: Node in get_tree().get_nodes_in_group(&"characters"):
			var other := node as Character
			if other != for_character and other.is_alive:
				nearest_enemy = minf(nearest_enemy, other.global_position.distance_to(spawn.global_position))
		if nearest_enemy > best_distance:
			best_distance = nearest_enemy
			best = spawn.global_transform
	return best


# Quem machucou `character` há pouco (crédito da queda), ou null.
func _recent_attacker(character: Character) -> Character:
	var credit: Array = _last_attackers.get(character, [])
	if credit.is_empty():
		return null
	var attacker := credit[0] as Character
	return attacker if attacker != character else null


## Resolve um tiro: aplica mira assistida e imprecisão, lança o raio e avisa quem foi atingido.
## Precisa rodar dentro do passo de física (usa o espaço físico direto).
func resolve_shot(shooter: Character, weapon: Weapon, origin: Vector3, direction: Vector3,
		aim_assist: bool) -> ShotResult:
	var result := ShotResult.new()
	result.shooter = shooter
	result.weapon = weapon
	result.origin = origin

	var aim: Vector3 = direction.normalized()
	if aim_assist:
		var target: Character = _find_assist_target(shooter, origin, aim, weapon.max_range)
		if target != null:
			aim = (_chest_of(target) - origin).normalized()
			result.assisted = true

	# A espingarda solta vários chumbos de uma vez: cada um é um raio, com a sua imprecisão.
	var pellets: int = maxi(weapon.pellets, 1)
	var damage_by_victim: Dictionary[Character, float] = {}
	for pellet: int in pellets:
		var pellet_aim: Vector3 = _apply_spread(aim, weapon.spread_degrees)
		var end_point: Vector3 = origin + pellet_aim * weapon.max_range
		var hit: Dictionary = _ray(shooter, origin, end_point)
		var victim: Character = null
		if not hit.is_empty():
			end_point = hit.position
			victim = hit.collider as Character
			if pellet == 0 or not result.hit:
				result.hit = true
				result.hit_normal = hit.normal
		if pellet == 0:
			result.direction = pellet_aim
			result.end_point = end_point
		else:
			result.pellet_points.append(end_point)
		if victim != null:
			var applied: float = apply_damage(victim, weapon.damage, shooter)
			damage_by_victim[victim] = damage_by_victim.get(victim, 0.0) + applied
			result.damage += applied

	# Quem levou mais chumbo é "a vítima" do tiro (som do acerto, marcador do HUD).
	for victim: Character in damage_by_victim:
		if result.victim == null or damage_by_victim[victim] > damage_by_victim[result.victim]:
			result.victim = victim
	for victim: Character in damage_by_victim:
		victim.receive_hit(result)

	shot_resolved.emit(result)
	return result


# Alvo mais perto do centro da mira, dentro do cone e da distância lateral, e à vista.
func _find_assist_target(shooter: Character, origin: Vector3, aim: Vector3, max_range: float) -> Character:
	var best: Character = null
	var best_angle: float = deg_to_rad(assist_max_angle)
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var candidate := node as Character
		if candidate == shooter or not candidate.is_alive:
			continue
		var to_target: Vector3 = _chest_of(candidate) - origin
		var distance: float = to_target.length()
		if distance < 0.01 or distance > max_range:
			continue
		var angle: float = aim.angle_to(to_target)
		if angle > best_angle or sin(angle) * distance > assist_max_offset:
			continue
		# Só ajuda se o alvo estiver à vista (parede no meio = sem ajuda).
		if _ray(shooter, origin, _chest_of(candidate)).get("collider") != candidate:
			continue
		best = candidate
		best_angle = angle
	return best


func _chest_of(character: Character) -> Vector3:
	return character.global_position + Vector3.UP * CHEST_HEIGHT


func _apply_spread(aim: Vector3, spread_degrees: float) -> Vector3:
	if spread_degrees <= 0.0:
		return aim
	# Inclina o tiro até `spread_degrees` e gira essa inclinação em volta da mira.
	var tilt: float = deg_to_rad(spread_degrees) * sqrt(_rng.randf())
	var side: Vector3 = aim.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = aim.cross(Vector3.RIGHT)
	return aim.rotated(side.normalized(), tilt).rotated(aim, _rng.randf() * TAU)


func _ray(shooter: Character, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [shooter.get_rid()]
	return shooter.get_world_3d().direct_space_state.intersect_ray(query)
