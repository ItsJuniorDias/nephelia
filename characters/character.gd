class_name Character
extends CharacterBody3D
## Personagem da arena: anda, pula e olha obedecendo ao comando do seu controlador.
##
## O personagem nunca lê teclado, toque ou IA diretamente: quem decide é o CharacterController
## filho dele (humano, bot ou, no futuro, rede). Assim o mesmo personagem serve para todos.
## Vida, morte e respawn também não são decididos aqui: quem manda é o MatchReferee (o juiz).

## Levou um tiro (o MatchReferee decidiu).
signal hit_received(result: ShotResult)
signal health_changed(health: float, max_health: float)
## Morreu. `killer` é null quando foi queda ou outro acidente.
signal died(killer: Character)
signal respawned

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

@export_group("Vida")
@export_range(1.0, 500.0, 1.0) var max_health: float = 100.0

@export_group("Aparência")
## Nome mostrado no HUD (ex.: "eliminado por ..."). Vazio = nome do nó.
@export var display_name: String = ""
## Cor de identificação (tinge a roupa do modelo; uma por jogador/bot).
@export var body_color: Color = Color(0.85, 0.85, 0.8)

## Para onde o corpo aponta (radianos).
var yaw: float:
	get:
		return rotation.y
## Inclinação da cabeça (radianos, positivo = para cima).
var pitch: float:
	get:
		return head.rotation.x
var health: float = 0.0
var is_alive: bool = true
## Acabou de nascer: não leva dano por alguns segundos (ou até atirar).
var is_spawn_protected: bool:
	get:
		return _protection_timer > 0.0

var controller: CharacterController
var weapon: Weapon

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_jump_held: bool = false
var _protection_timer: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var model: CharacterModel = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"characters")
	if display_name.is_empty():
		display_name = name
	health = max_health
	model.tint = body_color

	for child: Node in get_children():
		if child is Weapon and weapon == null:
			weapon = child as Weapon
		elif child is CharacterController and controller == null:
			controller = child as CharacterController
	# A arma primeiro: o controlador humano liga a mira e o contador de balas nela.
	if weapon != null:
		weapon.setup(self)
		weapon.fired.connect(model.play_shoot.unbind(1))
	if controller != null:
		controller.setup(self)


func _physics_process(delta: float) -> void:
	# Morto fica caído, sem colisão, até o juiz mandar renascer.
	if not is_alive:
		return
	if _protection_timer > 0.0:
		_protection_timer -= delta
		if _protection_timer <= 0.0:
			end_spawn_protection()

	var move := Vector2.ZERO
	var jump_held: bool = false
	if controller != null:
		var command: CharacterCommand = controller.get_command(delta)
		apply_look(command.yaw, command.pitch)
		move = command.move
		jump_held = command.jump
		if weapon != null:
			weapon.tick(delta, command)

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
	model.update_motion(Vector2(velocity.x, velocity.z).length(), pitch)


## Aponta o corpo (yaw) e a cabeça (pitch). A inclinação fica limitada a ±max_pitch_degrees.
func apply_look(new_yaw: float, new_pitch: float) -> void:
	rotation.y = wrapf(new_yaw, -PI, PI)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(new_pitch, -max_pitch, max_pitch)


## Chamado pelo MatchReferee quando um tiro acerta este personagem (já com o dano decidido).
func receive_hit(result: ShotResult) -> void:
	# Tranco e brilho branco: resposta visual imediata de que o tiro pegou.
	if result.damage > 0.0:
		model.play_hit()
	hit_received.emit(result)


## Muda a vida (só o MatchReferee deve chamar).
func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


## Morre: cai (animação), deixa de colidir e para de obedecer comandos (só o MatchReferee deve chamar).
func die(killer: Character) -> void:
	if not is_alive:
		return
	is_alive = false
	health = 0.0
	velocity = Vector3.ZERO
	_protection_timer = 0.0
	model.set_protected(false)
	model.play_death()
	# set_deferred: mudar colisão no meio do passo de física não é permitido.
	collision_shape.set_deferred(&"disabled", true)
	health_changed.emit(health, max_health)
	died.emit(killer)


## Renasce em `at` com vida cheia, arma cheia e proteção (só o MatchReferee deve chamar).
func respawn(at: Transform3D, protection_time: float) -> void:
	teleport(at)
	is_alive = true
	_was_jump_held = false
	model.reset_alive()
	collision_shape.set_deferred(&"disabled", false)
	if weapon != null:
		weapon.refill()
	set_health(max_health)
	_protection_timer = protection_time
	model.set_protected(protection_time > 0.0)
	respawned.emit()


## Tira a proteção de nascimento (acaba sozinha ou quando o personagem atira).
func end_spawn_protection() -> void:
	_protection_timer = 0.0
	model.set_protected(false)


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
