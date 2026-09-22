class_name BotController
extends CharacterController
## Controlador de bot (versão de teste): passeia entre pontos sorteados perto de onde nasceu.
##
## A IA de verdade (navmesh, achar inimigos, atirar) vem na tarefa de bots. Este bot já prova
## que o personagem obedece a qualquer controlador, sem ler teclado nem toque.

const STUCK_CHECK_INTERVAL: float = 1.5
const STUCK_MIN_DISTANCE: float = 0.3
## Só anda quando já está quase de frente para o destino (curvas mais naturais).
const WALK_MAX_ANGLE: float = deg_to_rad(45.0)

@export_range(0.5, 30.0, 0.5, "suffix:m") var wander_radius: float = 4.0
@export_range(0.1, 3.0, 0.1, "suffix:m") var arrive_distance: float = 0.8
@export_range(30.0, 720.0, 1.0, "suffix:°/s") var turn_speed: float = 240.0
## Semente do sorteio de destinos: com a mesma semente o passeio se repete (bom para testes).
@export var random_seed: int = 1

## Destino atual (dá para trocar de fora, ex.: nos testes).
var target: Vector3 = Vector3.ZERO

var _home: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _stuck_timer: float = 0.0
var _stuck_check_position: Vector3 = Vector3.ZERO


func setup(for_character: Character) -> void:
	super.setup(for_character)
	character.add_to_group(&"bots")
	character.respawned.connect(_on_respawned)
	_rng.seed = random_seed
	_home = character.global_position
	_stuck_check_position = _home
	pick_new_target()


## Sorteia um destino dentro de `wander_radius` em volta de casa.
func pick_new_target() -> void:
	var angle: float = _rng.randf() * TAU
	# sqrt() espalha os pontos por igual no círculo (sem ela, amontoam no centro).
	var distance: float = sqrt(_rng.randf()) * wander_radius
	target = _home + Vector3(cos(angle), 0.0, sin(angle)) * distance


func get_command(delta: float) -> CharacterCommand:
	command.reset()
	var to_target: Vector3 = target - character.global_position
	to_target.y = 0.0
	if to_target.length() < arrive_distance or _is_stuck(delta):
		pick_new_target()
		to_target = target - character.global_position
		to_target.y = 0.0

	# Frente do personagem é -Z, por isso os sinais negativos.
	var desired_yaw: float = atan2(-to_target.x, -to_target.z)
	command.yaw = rotate_toward(character.yaw, desired_yaw, deg_to_rad(turn_speed) * delta)
	command.pitch = 0.0
	if absf(angle_difference(character.yaw, desired_yaw)) < WALK_MAX_ANGLE:
		command.move = Vector2(0.0, -1.0)
	return command


# Preso numa parede ou quina: se quase não saiu do lugar em STUCK_CHECK_INTERVAL, desiste.
func _is_stuck(delta: float) -> bool:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_INTERVAL:
		return false
	_stuck_timer = 0.0
	var moved: float = character.global_position.distance_to(_stuck_check_position)
	_stuck_check_position = character.global_position
	return moved < STUCK_MIN_DISTANCE


# Renasceu em outro ponto: passa a passear em volta de lá.
func _on_respawned() -> void:
	_home = character.global_position
	_stuck_check_position = _home
	_stuck_timer = 0.0
	pick_new_target()
