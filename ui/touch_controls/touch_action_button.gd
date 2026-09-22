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
## Arte do pacote Kenney Mobile Controls (contorno branco, que tingimos).
const RING: Texture2D = preload("res://assets/ui/kenney/button_circle.png")
const TINT_IDLE := Color(1.0, 0.97, 0.9, 0.7)
const TINT_PRESSED := Color(1.0, 0.86, 0.45, 1.0)
## Fundo escuro por baixo do anel: sem ele o botão some contra o céu claro.
const SHADE_IDLE := Color(0.05, 0.07, 0.1, 0.25)
const SHADE_PRESSED := Color(0.05, 0.07, 0.1, 0.45)
const ICON_RATIO: float = 0.9

@export var action: StringName = &""
## Desenho de dentro do botão (mira, pulo, recarga...). Sem ícone, usa o texto.
@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
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
	var tint: Color = TINT_PRESSED if _pressed else TINT_IDLE
	draw_circle(center, radius * 0.94, SHADE_PRESSED if _pressed else SHADE_IDLE, true, -1.0, true)
	draw_texture_rect(RING, _square(center, radius * 2.0), false, tint)

	if icon != null:
		draw_texture_rect(icon, _square(center, radius * ICON_RATIO), false, tint)
		return
	if label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(radius * 0.36), 8)
	# draw_string() posiciona pela linha de base; isto centraliza o texto na vertical.
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - radius, baseline_y), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, tint)


# Quadrado de lado `side` centrado em `center`.
func _square(center: Vector2, side: float) -> Rect2:
	return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
