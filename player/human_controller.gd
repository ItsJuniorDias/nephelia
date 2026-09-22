class_name HumanController
extends CharacterController
## Controlador do jogador local: lê toque, teclado/mouse e controle pelo Input Map.

@export_group("Sensibilidade")
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity: float = 0.15
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var touch_look_sensitivity: float = 0.25
@export_range(10.0, 720.0, 1.0, "suffix:°/s") var gamepad_look_speed: float = 180.0

@export_group("Mira")
## Ajuda de mira no toque e no controle (no mouse nunca: lá a mira já é precisa).
@export var aim_assist_enabled: bool = true

var _using_gamepad: bool = false
var _view_model: ViewModel
var _death_tween: Tween

@onready var touch_controls: TouchControls = $TouchControls
@onready var hud: Hud = $Hud
@onready var match_hud: MatchHud = $MatchHud
@onready var match_result: MatchResult = $MatchResult


func setup(for_character: Character) -> void:
	super.setup(for_character)
	character.camera.current = true
	# O jogador não vê o próprio corpo, mas a sombra dele continua no chão.
	character.model.set_shadow_only(true)
	touch_controls.look_dragged.connect(_on_touch_look_dragged)
	character.died.connect(_on_died)
	character.respawned.connect(_on_respawned)
	hud.setup(character)
	_view_model = character.camera.get_node_or_null("ViewModel") as ViewModel
	if _view_model != null and character.weapon != null:
		_view_model.setup(character, character.weapon)
	# A partida pode ficar pronta depois do jogador: conectamos no fim do quadro.
	_connect_to_match.call_deferred()


func _exit_tree() -> void:
	# Não deixar o mouse preso se a cena for trocada.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Só observa qual aparelho o jogador está usando (decide a mira assistida); não consome nada.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_using_gamepad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3:
		_using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_using_gamepad = false


func _unhandled_input(event: InputEvent) -> void:
	if character == null:
		return
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
	if character == null:
		return
	# HOOK só aparece quando dá para engatar (ou para soltar, se já estiver pendurado).
	var can_hook: bool = character.is_alive and not character.is_on_rail \
			and not character.find_hookable_rail(rail_hook_cone).is_empty()
	touch_controls.set_action_visible(&"use_rail", character.is_on_rail or can_hook)
	hud.set_rail_hint(can_hook)
	# Analógico direito: gira a uma velocidade fixa por segundo (por isso * delta).
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		rotate_look(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)


func get_command(_delta: float) -> CharacterCommand:
	command.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# just_pressed pega toques rápidos que começam e terminam entre dois passos de física.
	command.jump = Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")
	command.fire = Input.is_action_pressed("fire") or Input.is_action_just_pressed("fire")
	command.reload = Input.is_action_just_pressed("reload")
	command.use_rail = Input.is_action_pressed("use_rail") or Input.is_action_just_pressed("use_rail")
	command.aim_assist = aim_assist_enabled and (TouchControls.is_touch_mode() or _using_gamepad)
	command.yaw = character.yaw
	command.pitch = character.pitch
	return command


## Gira o olhar na hora, sem esperar o passo de física, para a câmera responder no mesmo quadro.
## Positivo = virar para a ESQUERDA e olhar para CIMA.
func rotate_look(yaw_degrees: float, pitch_degrees: float) -> void:
	if not character.is_alive:
		return
	character.apply_look(character.yaw + deg_to_rad(yaw_degrees), character.pitch + deg_to_rad(pitch_degrees))


func _on_touch_look_dragged(relative: Vector2) -> void:
	# Arrastar para a direita vira para a direita; arrastar para cima olha para cima.
	rotate_look(-relative.x * touch_look_sensitivity, -relative.y * touch_look_sensitivity)


func _connect_to_match() -> void:
	var deathmatch: Deathmatch = Deathmatch.find(self)
	if deathmatch == null:
		match_hud.visible = false
		return
	match_hud.setup(character, deathmatch)
	match_result.setup(character, deathmatch)
	deathmatch.match_finished.connect(_on_match_finished.unbind(1))
	deathmatch.match_started.connect(_on_match_started)


# Fim de partida: solta o mouse (para clicar em "jogar de novo") e esconde o toque.
func _on_match_finished() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.enabled = false


func _on_match_started() -> void:
	touch_controls.enabled = true


# Câmera "cai" no chão e a arma some enquanto espera o respawn.
func _on_died(_killer: Character) -> void:
	if _view_model != null:
		_view_model.visible = false
	touch_controls.release_all()
	if _death_tween != null:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_death_tween.tween_property(character.camera, "position", Vector3(0.0, -1.2, 0.0), 0.6)
	_death_tween.tween_property(character.camera, "rotation:z", 0.4, 0.6)


func _on_respawned() -> void:
	if _death_tween != null:
		_death_tween.kill()
	character.camera.position = Vector3.ZERO
	character.camera.rotation = Vector3.ZERO
	if _view_model != null:
		_view_model.visible = true
