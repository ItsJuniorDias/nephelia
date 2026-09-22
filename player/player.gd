class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: anda, pula e olha com toque, teclado/mouse ou controle.
##
## Todos os comandos vêm do Input Map (move_*, look_*, jump, pause), então o mesmo
## código serve para celular, PC e controle.

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

@export_group("Câmera")
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity: float = 0.15
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var touch_look_sensitivity: float = 0.25
@export_range(10.0, 720.0, 1.0, "suffix:°/s") var gamepad_look_speed: float = 180.0
@export_range(10.0, 89.0, 1.0, "suffix:°") var max_pitch_degrees: float = 85.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var touch_controls: TouchControls = $TouchControls


func _ready() -> void:
	touch_controls.look_dragged.connect(_on_touch_look_dragged)


func _exit_tree() -> void:
	# Não deixar o mouse preso se a cena for trocada.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# No modo toque o mouse nunca é capturado: o olhar vem do TouchControls.
	if TouchControls.is_touch_mode():
		return

	var click := event as InputEventMouseButton
	if click != null and click.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative ignora o esticamento da tela: a sensibilidade não muda com a resolução.
		rotate_look(-motion.screen_relative.x * mouse_sensitivity, -motion.screen_relative.y * mouse_sensitivity)


func _process(delta: float) -> void:
	# Analógico direito: gira a uma velocidade fixa por segundo (por isso * delta).
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		rotate_look(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)


func _physics_process(delta: float) -> void:
	_update_jump_timers(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	var wants_jump: bool = Input.is_action_just_pressed("jump") or _jump_buffer_timer > 0.0
	if can_jump and wants_jump:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# A direção do comando é relativa para onde o corpo está virado.
	var direction: Vector3 = transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var target_velocity: Vector3 = direction * walk_speed
	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target_velocity.x, target_velocity.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()


## Gira o olhar. Positivo = virar para a ESQUERDA e olhar para CIMA (convenção do Godot).
func rotate_look(yaw_degrees: float, pitch_degrees: float) -> void:
	# O corpo gira no eixo Y; só a cabeça inclina para cima/baixo.
	rotation.y = wrapf(rotation.y + deg_to_rad(yaw_degrees), -PI, PI)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(head.rotation.x + deg_to_rad(pitch_degrees), -max_pitch, max_pitch)


## Leva o jogador até `target` (posição e direção), parado e olhando reto.
func teleport(target: Transform3D) -> void:
	global_position = target.origin
	global_rotation = Vector3(0.0, target.basis.orthonormalized().get_euler().y, 0.0)
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	reset_physics_interpolation()


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _on_touch_look_dragged(relative: Vector2) -> void:
	# Arrastar para a direita vira para a direita; arrastar para cima olha para cima.
	rotate_look(-relative.x * touch_look_sensitivity, -relative.y * touch_look_sensitivity)
