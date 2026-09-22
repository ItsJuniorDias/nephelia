class_name Character
extends CharacterBody3D
## Personagem da arena: anda, pula e olha obedecendo ao comando do seu controlador.
##
## O personagem nunca lê teclado, toque ou IA diretamente: quem decide é o CharacterController
## filho dele (humano, bot ou, no futuro, rede). Assim o mesmo personagem serve para todos.

@export_group("Movimento")
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 5.0
## Quão rápido chega à velocidade máxima no chão. Alto = resposta imediata.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var ground_acceleration: float = 40.0
## No ar o controle é menor, para o pulo ter peso.
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var air_acceleration: float = 10.0
@export_range(1.0, 15.0, 0.1, "suffix:m/s") var jump_velocity: float = 4.8
## Depois de sair de uma borda, ainda dá para pular durante este tempo (perdoa o atraso do dedo).
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time: float = 0.12
## Apertar "pular" um pouco antes de tocar o chão ainda vale durante este tempo.
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time: float = 0.12

@export_group("Olhar")
@export_range(10.0, 89.0, 1.0, "suffix:°") var max_pitch_degrees: float = 85.0

@export_group("Aparência")
## Cor provisória do corpo (uma por jogador/bot), até entrarem os modelos 3D.
@export var body_color: Color = Color(0.85, 0.85, 0.8)

## Para onde o corpo aponta (radianos).
var yaw: float:
	get:
		return rotation.y
## Inclinação da cabeça (radianos, positivo = para cima).
var pitch: float:
	get:
		return head.rotation.x

var controller: CharacterController

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_jump_held: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $Body
@onready var visor_mesh: MeshInstance3D = $Head/Visor


func _ready() -> void:
	add_to_group(&"characters")
	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	body_mesh.material_override = material

	for child: Node in get_children():
		if child is CharacterController:
			controller = child as CharacterController
			controller.setup(self)
			break


func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	var jump_held: bool = false
	if controller != null:
		var command: CharacterCommand = controller.get_command(delta)
		apply_look(command.yaw, command.pitch)
		move = command.move
		jump_held = command.jump

	# O comando diz se "pular" está apertado; o pulo acontece só no instante em que aperta.
	var jump_pressed: bool = jump_held and not _was_jump_held
	_was_jump_held = jump_held
	_update_jump_timers(delta, jump_pressed)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	if can_jump and _jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# A direção do comando é relativa para onde o corpo está virado.
	var direction: Vector3 = transform.basis * Vector3(move.x, 0.0, move.y)
	var target_velocity: Vector3 = direction * walk_speed
	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target_velocity.x, target_velocity.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()


## Aponta o corpo (yaw) e a cabeça (pitch). A inclinação fica limitada a ±max_pitch_degrees.
func apply_look(new_yaw: float, new_pitch: float) -> void:
	rotation.y = wrapf(new_yaw, -PI, PI)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(new_pitch, -max_pitch, max_pitch)


## Leva o personagem até `target` (posição e direção), parado e olhando reto.
func teleport(target: Transform3D) -> void:
	global_position = target.origin
	global_rotation = Vector3(0.0, target.basis.orthonormalized().get_euler().y, 0.0)
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	reset_physics_interpolation()


func _update_jump_timers(delta: float, jump_pressed: bool) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if jump_pressed:
		_jump_buffer_timer = maxf(jump_buffer_time, delta)
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
