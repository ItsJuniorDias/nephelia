class_name MatchReferee
extends Node
## Juiz da partida: decide se cada tiro acertou e em quem.
##
## Hoje roda no próprio aparelho. No multiplayer só o servidor terá o juiz, e é isso que
## impede trapaça: o jogador só diz "atirei nesta direção"; quem decide o acerto é o juiz.

signal shot_resolved(result: ShotResult)

const GROUP: StringName = &"match_referee"
## Altura, a partir dos pés, do ponto que a mira assistida procura no alvo (peito).
const CHEST_HEIGHT: float = 1.2

@export_group("Mira assistida")
## Ângulo máximo entre a mira e o alvo para a ajuda agir.
@export_range(0.0, 20.0, 0.5, "suffix:°") var assist_max_angle: float = 8.0
## Distância máxima entre a linha da mira e o alvo. Evita ajuda exagerada em alvos longe.
@export_range(0.0, 5.0, 0.1, "suffix:m") var assist_max_offset: float = 1.0

var _rng := RandomNumberGenerator.new()


## Acha o juiz da cena atual (ou null se não houver).
static func find(from: Node) -> MatchReferee:
	return from.get_tree().get_first_node_in_group(GROUP) as MatchReferee


func _ready() -> void:
	add_to_group(GROUP)


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
	aim = _apply_spread(aim, weapon.spread_degrees)
	result.direction = aim

	var hit: Dictionary = _ray(shooter, origin, origin + aim * weapon.max_range)
	if hit.is_empty():
		result.end_point = origin + aim * weapon.max_range
	else:
		result.hit = true
		result.end_point = hit.position
		result.hit_normal = hit.normal
		result.victim = hit.collider as Character
		if result.victim != null:
			result.damage = weapon.damage
			result.victim.receive_hit(result)

	shot_resolved.emit(result)
	return result


# Alvo mais perto do centro da mira, dentro do cone e da distância lateral, e à vista.
func _find_assist_target(shooter: Character, origin: Vector3, aim: Vector3, max_range: float) -> Character:
	var best: Character = null
	var best_angle: float = deg_to_rad(assist_max_angle)
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var candidate := node as Character
		if candidate == shooter:
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
