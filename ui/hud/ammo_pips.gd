class_name AmmoPips
extends Control
## Munição do HUD: uma bala desenhada para cada tiro do tambor, com o nome da arma em cima e a
## munição guardada ao lado.
##
## Balas cheias à esquerda, vazias à direita. Recarregando, elas se acendem uma a uma no
## ritmo da recarga (dá para ver quanto falta sem olhar número nenhum). A reserva só aparece
## nas armas pegas na arena: o revólver nunca acaba.

const FULL := Color(1.0, 0.86, 0.45)
const EMPTY := Color(0.35, 0.33, 0.3, 0.55)
const OUTLINE := Color(0.05, 0.07, 0.1, 0.65)
const NAME_COLOR := Color(1.0, 0.94, 0.82, 0.85)
const SPACING: float = 6.0

var ammo: int = 6
var magazine: int = 6
var reloading: bool = false
## Quanto da recarga já passou, de 0 a 1.
var reload_progress: float = 0.0
## Munição fora do tambor (-1 = infinita, não aparece).
var reserve: int = -1
var weapon_name: String = ""


func show_ammo(value: int, size_of_magazine: int, is_reloading: bool, progress: float,
		spare: int = -1, shown_name: String = "") -> void:
	ammo = value
	magazine = maxi(size_of_magazine, 1)
	reloading = is_reloading
	reload_progress = progress
	reserve = spare
	weapon_name = shown_name
	queue_redraw()


func _draw() -> void:
	# Caixa preta com borda de cobre do kit (a da lista suspensa) atrás das balas e da reserva.
	var backdrop: StyleBox = get_theme_stylebox(&"normal", &"OptionButton")
	var reserve_room: float = 34.0 if reserve >= 0 else 0.0
	draw_style_box(backdrop, Rect2(Vector2(-10.0, -7.0), size + Vector2(20.0 + reserve_room, 14.0)))
	var count: int = magazine
	var pip_width: float = (size.x - SPACING * (count - 1)) / count
	var filled: int = ammo
	if reloading:
		# Enche da esquerda para a direita conforme a recarga anda.
		filled = floori(reload_progress * count)
	for i in count:
		var rect := Rect2(Vector2(i * (pip_width + SPACING), 0.0), Vector2(pip_width, size.y))
		draw_rect(rect.grow(1.0), OUTLINE, true)
		draw_rect(rect, FULL if i < filled else EMPTY, true)

	var font: Font = get_theme_default_font()
	# Contorno escuro em volta das letras: sem ele o texto some contra o chão claro da praça.
	if not weapon_name.is_empty():
		var name_at := Vector2(0.0, -8.0)
		draw_string_outline(font, name_at, weapon_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 14, 4, OUTLINE)
		draw_string(font, name_at, weapon_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 14, NAME_COLOR)
	# Reserva ao lado das balas (fora do retângulo, onde não há nada).
	if reserve >= 0:
		var baseline: float = size.y * 0.5 + (font.get_ascent(15) - font.get_descent(15)) * 0.5
		var reserve_at := Vector2(size.x + 8.0, baseline)
		draw_string_outline(font, reserve_at, "x%d" % reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, OUTLINE)
		draw_string(font, reserve_at, "x%d" % reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, FULL)
