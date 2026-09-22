@tool
class_name TouchActionButton
extends Control
## Botão redondo de toque que aperta uma ação do Input Map (ex.: "fire", "jump").
##
## Quem decide qual dedo aperta o botão é o TouchControls (press/release).
## O botão continua apertado se o dedo escorregar para fora; só solta quando o dedo sai da tela.

# @tool só para o botão aparecer desenhado no editor e facilitar o ajuste da posição.

# Folga extra no toque: dedos são imprecisos, melhor aceitar um pouco fora do círculo.
const HIT_SLOP: float = 12.0
const FILL_IDLE := Color(0.95, 0.91, 0.82, 0.18)
const FILL_PRESSED := Color(0.95, 0.91, 0.82, 0.5)
const OUTLINE_IDLE := Color(0.79, 0.64, 0.29, 0.75)
const OUTLINE_PRESSED := Color(0.98, 0.84, 0.45, 1.0)
const LABEL_IDLE := Color(1.0, 0.97, 0.9, 0.8)
const LABEL_PRESSED := Color(1.0, 1.0, 1.0, 1.0)

@export var action: StringName = &""
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()
@export_range(20.0, 150.0, 1.0, "suffix:px") var radius: float = 60.0:
	set(value):
		radius = value
		queue_redraw()

var _pressed: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		# Nunca deixar uma ação "presa" se o botão sair da cena.
		release()


## Teste de toque em círculo. `p` está em coordenadas da viewport.
func contains_point(p: Vector2) -> bool:
	var local_point: Vector2 = get_global_transform().affine_inverse() * p
	return local_point.distance_to(size * 0.5) <= radius + HIT_SLOP


func press() -> void:
	if _pressed:
		return
	if not InputMap.has_action(action):
		push_warning("TouchActionButton '%s': a ação '%s' não existe no Input Map." % [name, action])
		return
	_pressed = true
	Input.action_press(action)
	queue_redraw()


func release() -> void:
	# Só solta se fomos nós que apertamos: action_release() limpa a ação inteira (teclado/controle também).
	if not _pressed:
		return
	_pressed = false
	Input.action_release(action)
	queue_redraw()


func is_pressed() -> bool:
	return _pressed


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var fill: Color = FILL_PRESSED if _pressed else FILL_IDLE
	var outline: Color = OUTLINE_PRESSED if _pressed else OUTLINE_IDLE
	draw_circle(center, radius, fill, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, outline, 3.0, true)

	if label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(radius * 0.36), 8)
	# draw_string() posiciona pela linha de base; isto centraliza o texto na vertical.
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var label_color: Color = LABEL_PRESSED if _pressed else LABEL_IDLE
	draw_string(font, Vector2(center.x - radius, baseline_y), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, label_color)
