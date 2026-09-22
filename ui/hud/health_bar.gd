class_name HealthBar
extends Control
## Barra de vida do HUD: desenhada em código (barra, borda de latão e o número dentro).
##
## A cor vai do verde ao vermelho conforme a vida cai, e a barra "escorre" até o valor novo,
## para o dano ser visível mesmo quando a tela está cheia de coisa.

const BACKGROUND := Color(0.05, 0.07, 0.1, 0.55)
const BORDER := Color(0.85, 0.7, 0.38, 0.85)
## Dourado como o resto da interface; vira vermelho quando a vida cai.
const FULL_COLOR := Color(0.88, 0.73, 0.4)
const LOW_COLOR := Color(0.9, 0.25, 0.2)
## Rastro claro que mostra quanto acabou de ser perdido.
const TRAIL_COLOR := Color(1.0, 0.85, 0.5, 0.55)
const TRAIL_SPEED: float = 0.45
const CORNER: float = 6.0

var health: float = 100.0
var max_health: float = 100.0

var _trail: float = 1.0


func _ready() -> void:
	set_process(true)


## Mostra a vida nova (o rastro alcança em seguida).
func set_health(value: float, maximum: float) -> void:
	health = value
	max_health = maxf(maximum, 0.001)
	if value >= maximum:
		_trail = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	var target: float = health / max_health
	if absf(_trail - target) < 0.001:
		return
	_trail = move_toward(_trail, target, delta * TRAIL_SPEED)
	queue_redraw()


func _draw() -> void:
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, BACKGROUND, true)
	if _trail > ratio:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _trail, size.y)), TRAIL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), LOW_COLOR.lerp(FULL_COLOR, ratio), true)
	draw_rect(full, BORDER, false, 2.0)

	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(size.y * 0.7), 10)
	var baseline: float = size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(10.0, baseline), "%d" % roundi(health), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 20.0, font_size, Color(1.0, 0.98, 0.94))
