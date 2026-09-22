class_name AmmoPips
extends Control
## Munição do HUD: uma bala desenhada para cada tiro do tambor.
##
## Balas cheias à esquerda, vazias à direita. Recarregando, elas se acendem uma a uma no
## ritmo da recarga (dá para ver quanto falta sem olhar número nenhum).

const FULL := Color(1.0, 0.86, 0.45)
const EMPTY := Color(0.35, 0.33, 0.3, 0.55)
const OUTLINE := Color(0.05, 0.07, 0.1, 0.65)
const SPACING: float = 6.0

var ammo: int = 6
var magazine: int = 6
var reloading: bool = false
## Quanto da recarga já passou, de 0 a 1.
var reload_progress: float = 0.0


func show_ammo(value: int, size_of_magazine: int, is_reloading: bool, progress: float) -> void:
	ammo = value
	magazine = maxi(size_of_magazine, 1)
	reloading = is_reloading
	reload_progress = progress
	queue_redraw()


func _draw() -> void:
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
