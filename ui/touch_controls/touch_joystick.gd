@tool
class_name TouchJoystick
extends Control
## Joystick virtual flutuante: nasce onde o dedo toca e aperta as ações de movimento.
##
## Quem decide qual dedo controla o joystick é o TouchControls (begin/drag/end).

# @tool só para o joystick aparecer desenhado no editor e facilitar o ajuste da posição.

const BASE_FILL := Color(0.95, 0.91, 0.82, 0.18)
const BASE_OUTLINE := Color(0.79, 0.64, 0.29, 0.75)
const KNOB_FILL := Color(0.95, 0.91, 0.82, 0.55)
const KNOB_RATIO: float = 0.45
# Parado, o joystick fica mais apagado: é só uma dica de onde pôr o dedão.
const IDLE_ALPHA: float = 0.5

@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_forward"
@export var action_down: StringName = &"move_back"
## Distância máxima (em pixels) que o pino pode se afastar do centro.
@export_range(30.0, 200.0, 1.0, "suffix:px") var radius: float = 90.0:
	set(value):
		radius = value
		queue_redraw()

## Direção atual, comprimento de 0 a 1. Só para leitura.
var output: Vector2 = Vector2.ZERO

var _finger: int = -1
var _base: Vector2 = Vector2.ZERO # centro atual, em coordenadas locais
# Ações que ESTE joystick apertou. Input.action_release() limpa a ação inteira
# (inclusive o teclado), então só soltamos o que nós mesmos apertamos.
var _held: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_base = _rest_position()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not is_active():
		_base = _rest_position()
		queue_redraw()
	elif what == NOTIFICATION_EXIT_TREE:
		# Nunca deixar o jogador andando sozinho se o nó sair da cena.
		end()


## Começa a controlar: a base vai para onde o dedo tocou (joystick flutuante).
func begin(finger: int, at: Vector2) -> void:
	_finger = finger
	_base = _viewport_to_local(at)
	output = Vector2.ZERO
	queue_redraw()


func drag(at: Vector2) -> void:
	if not is_active():
		return
	var offset: Vector2 = _viewport_to_local(at) - _base
	output = (offset / maxf(radius, 1.0)).limit_length(1.0)
	# Sem zona morta extra aqui: a do Input Map (0.2) já vale no Input.get_vector().
	_apply_axis(action_left, action_right, output.x)
	_apply_axis(action_up, action_down, output.y)
	queue_redraw()


func end() -> void:
	_finger = -1
	output = Vector2.ZERO
	for action: StringName in _held.keys():
		Input.action_release(action)
	_held.clear()
	_base = _rest_position()
	queue_redraw()


func is_active() -> bool:
	return _finger >= 0


func _draw() -> void:
	var alpha: float = 1.0 if is_active() else IDLE_ALPHA
	var knob_center: Vector2 = _base + output * radius
	draw_circle(_base, radius, Color(BASE_FILL, BASE_FILL.a * alpha), true, -1.0, true)
	draw_arc(_base, radius, 0.0, TAU, 64, Color(BASE_OUTLINE, BASE_OUTLINE.a * alpha), 3.0, true)
	draw_circle(knob_center, radius * KNOB_RATIO, Color(KNOB_FILL, KNOB_FILL.a * alpha), true, -1.0, true)
	draw_arc(knob_center, radius * KNOB_RATIO, 0.0, TAU, 48, Color(BASE_OUTLINE, BASE_OUTLINE.a * alpha), 2.0, true)


# Valor negativo aperta a ação "negativa" (esquerda/frente) e solta a oposta.
func _apply_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	if value < 0.0:
		_set_action(negative_action, -value)
		_set_action(positive_action, 0.0)
	else:
		_set_action(positive_action, value)
		_set_action(negative_action, 0.0)


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	elif _held.has(action):
		Input.action_release(action)
		_held.erase(action)


func _rest_position() -> Vector2:
	return size * 0.5


# Os eventos de toque chegam em coordenadas da viewport; o desenho usa coordenadas locais.
func _viewport_to_local(at: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * at
