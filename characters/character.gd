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
## Pegou um item (o MatchReferee decidiu).
signal picked_up(pickup: Pickup)
signal rail_attached(rail: SkylineRail)
signal rail_detached

## Pendurado no trilho, os pés ficam esta distância abaixo dele.
const RAIL_HANG: float = 2.0
## Alcance para engatar num trilho (do olho até o ponto do trilho).
const RAIL_HOOK_RANGE: float = 10.0
## Velocidade com que o personagem é puxado até o trilho ao engatar.
const RAIL_ZIP_SPEED: float = 25.0
## Ao chegar no fim do trilho, sai com esta fração da velocidade (não é arremessado da ilha).
const RAIL_END_KEEP: float = 0.3

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

@export_group("Trilho aéreo")
@export_range(3.0, 30.0, 0.5, "suffix:m/s") var rail_speed: float = 13.0
## Velocidade extra segurando "para frente" no trilho.
@export_range(0.0, 15.0, 0.5, "suffix:m/s") var rail_boost: float = 4.0

@export_group("Vida")
@export_range(1.0, 500.0, 1.0) var max_health: float = 100.0

@export_group("Aparência")
## Nome mostrado no HUD (ex.: "eliminado por ..."). Vazio = nome do nó.
@export var display_name: String = ""
## Cor de identificação (tinge a roupa do modelo; uma por jogador/bot).
@export var body_color: Color = Color(0.85, 0.85, 0.8)
## Corpo, roupa, cabelo e chapéu (vazio = o padrão da CharacterLook).
@export var look: CharacterLook

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

## Pendurado num trilho aéreo agora.
var is_on_rail: bool:
	get:
		return rail != null
## Engatou e ainda está sendo puxado até o trilho (ainda não desliza).
var is_rail_pulling: bool:
	get:
		return rail != null and _rail_zipping
var rail: SkylineRail

var controller: CharacterController
var weapon: Weapon

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_jump_held: bool = false
var _protection_timer: float = 0.0
var _was_rail_held: bool = false
var _rail_offset: float = 0.0
var _rail_direction: float = 1.0
var _rail_current_speed: float = 0.0
var _rail_zipping: bool = false
## Acabou de soltar do trilho: o "está no chão" do Godot ainda é o de antes de engatar
## (pendurado não passa pelo move_and_slide), então vale "no ar" até o próximo movimento.
var _left_rail: bool = false

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
		weapon.weapon_changed.connect(model.set_weapon)
		model.set_weapon(weapon.data)
		model.mount.watch(weapon)
	if controller != null:
		controller.setup(self)
	# Sons do personagem (passos, pulo, dano, trilho...), criados em código como a arma.
	var sounds := CharacterAudio.new()
	add_child(sounds)
	sounds.setup(self)


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
	var rail_held: bool = false
	if controller != null:
		var command: CharacterCommand = controller.get_command(delta)
		apply_look(command.yaw, command.pitch)
		move = command.move
		jump_held = command.jump
		rail_held = command.use_rail
		if weapon != null:
			weapon.tick(delta, command)

	# O comando diz se o botão está apertado; a ação acontece só no instante em que aperta.
	var jump_pressed: bool = jump_held and not _was_jump_held
	_was_jump_held = jump_held
	var rail_pressed: bool = rail_held and not _was_rail_held
	_was_rail_held = rail_held

	if is_on_rail:
		_ride_rail(delta, move, jump_pressed, rail_pressed)
		model.update_motion(0.0, pitch, true)
		return
	if rail_pressed and controller != null:
		var hook: Dictionary = find_hookable_rail(controller.rail_hook_cone)
		if not hook.is_empty():
			attach_to_rail(hook["rail"], hook["offset"])
			return

	var grounded: bool = is_grounded()
	_update_jump_timers(delta, jump_pressed, grounded)

	if not grounded:
		velocity.y -= _gravity * delta

	var can_jump: bool = grounded or _coyote_timer > 0.0
	if can_jump and _jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# A direção do comando é relativa para onde o corpo está virado.
	var direction: Vector3 = transform.basis * Vector3(move.x, 0.0, move.y)
	var target_velocity: Vector3 = direction * walk_speed
	var acceleration: float = ground_acceleration if grounded else air_acceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target_velocity.x, target_velocity.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()
	_left_rail = false
	model.update_motion(Vector2(velocity.x, velocity.z).length(), pitch, not is_on_floor())


## Está no chão (como is_on_floor(), mas sem o valor velho logo depois de soltar do trilho).
func is_grounded() -> bool:
	return is_on_floor() and not _left_rail


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
## O juiz deu um item a este personagem (efeito já aplicado): só avisa quem mostra (HUD).
func receive_pickup(pickup: Pickup) -> void:
	picked_up.emit(pickup)


func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


## Morre: cai (animação), deixa de colidir e para de obedecer comandos (só o MatchReferee deve chamar).
func die(killer: Character) -> void:
	if not is_alive:
		return
	detach_from_rail(Vector3.ZERO)
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
	detach_from_rail(Vector3.ZERO)
	global_position = target.origin
	global_rotation = Vector3(0.0, target.basis.orthonormalized().get_euler().y, 0.0)
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	reset_physics_interpolation()


## Trilho ao alcance dentro do cone do olhar: {"rail": SkylineRail, "offset": float}, ou {}.
func find_hookable_rail(cone: float = deg_to_rad(30.0)) -> Dictionary:
	var eye: Vector3 = head.global_position
	var look: Vector3 = -head.global_basis.z
	var best: Dictionary = {}
	var best_angle: float = cone
	for node: Node in get_tree().get_nodes_in_group(SkylineRail.GROUP):
		var candidate := node as SkylineRail
		# Procura o ponto do trilho mais perto de alguns pontos ao longo da linha do olhar.
		for distance: float in [0.0, 2.5, 5.0, 7.5, 10.0]:
			var offset: float = candidate.closest_offset(eye + look * distance)
			var to_point: Vector3 = candidate.point_at(offset) - eye
			if to_point.length() > RAIL_HOOK_RANGE:
				continue
			var angle: float = look.angle_to(to_point) if to_point.length() > 0.01 else 0.0
			if angle <= best_angle:
				best_angle = angle
				best = {"rail": candidate, "offset": offset}
	return best


## Engata no trilho: é puxado até ficar pendurado e segue no sentido para onde está virado.
func attach_to_rail(target: SkylineRail, offset: float) -> void:
	rail = target
	_rail_offset = offset
	var forward: Vector3 = -global_basis.z
	_rail_direction = 1.0 if target.tangent_at(offset).dot(forward) >= 0.0 else -1.0
	_rail_current_speed = maxf(Vector2(velocity.x, velocity.z).length(), rail_speed * 0.6)
	_rail_zipping = true
	velocity = Vector3.ZERO
	model.set_hanging(true, RAIL_HANG)
	rail_attached.emit(target)


## Solta do trilho saindo com `new_velocity` (nada acontece se não estiver num trilho).
func detach_from_rail(new_velocity: Vector3) -> void:
	if rail == null:
		return
	rail = null
	_rail_zipping = false
	_left_rail = true
	velocity = new_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	model.set_hanging(false)
	rail_detached.emit()


func _ride_rail(delta: float, move: Vector2, jump_pressed: bool, rail_pressed: bool) -> void:
	var hang_point: Vector3 = rail.point_at(_rail_offset) + Vector3.DOWN * RAIL_HANG
	# Primeiro é puxado até o trilho.
	if _rail_zipping:
		global_position = global_position.move_toward(hang_point, RAIL_ZIP_SPEED * delta)
		_rail_zipping = global_position.distance_to(hang_point) > 0.05
		if jump_pressed or rail_pressed:
			detach_from_rail(Vector3.ZERO)
		return

	# Para frente acelera, para trás freia.
	var target_speed: float = rail_speed
	if move.y < -0.5:
		target_speed += rail_boost
	elif move.y > 0.5:
		target_speed *= 0.4
	_rail_current_speed = move_toward(_rail_current_speed, target_speed, 15.0 * delta)
	_rail_offset += _rail_direction * _rail_current_speed * delta
	var length: float = rail.get_length()
	var reached_end: bool = _rail_offset <= 0.0 or _rail_offset >= length
	_rail_offset = clampf(_rail_offset, 0.0, length)
	velocity = rail.tangent_at(_rail_offset) * _rail_direction * _rail_current_speed
	global_position = rail.point_at(_rail_offset) + Vector3.DOWN * RAIL_HANG

	if reached_end:
		detach_from_rail(velocity * RAIL_END_KEEP)
	elif jump_pressed:
		detach_from_rail(velocity + Vector3.UP * jump_velocity)
	elif rail_pressed:
		detach_from_rail(velocity)


func _update_jump_timers(delta: float, jump_pressed: bool, grounded: bool) -> void:
	if grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if jump_pressed:
		_jump_buffer_timer = maxf(jump_buffer_time, delta)
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
