class_name HealthBar
extends Control
## Barra de vida do HUD: trilho e preenchimento do Marble and Gold UI Kit (os estilos da
## ProgressBar no tema), com o número dentro.
##
## O preenchimento (laranja, como os sliders) vai para o vermelho conforme a vida cai, e a barra
## "escorre" até o valor novo, para o dano ser visível mesmo quando a tela está cheia de coisa.

## Tinta do preenchimento: branco = a cor do kit; vermelho com pouca vida.
const FULL_COLOR := Color(1.0, 1.0, 1.0)
const LOW_COLOR := Color(1.3, 0.35, 0.3)
## Rastro claro que mostra quanto acabou de ser perdido.
const TRAIL_COLOR := Color(1.8, 1.6, 1.2, 0.5)
const TRAIL_SPEED: float = 0.45

var health: float = 100.0
var max_health: float = 100.0

var _trail: float = 1.0
var _track: StyleBox
var _fill: StyleBoxTexture


func _ready() -> void:
	_track = get_theme_stylebox(&"background", &"ProgressBar")
	# Cópia: a tinta muda com a vida (o estilo do tema é compartilhado).
	_fill = (get_theme_stylebox(&"fill", &"ProgressBar") as StyleBoxTexture).duplicate()
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
	draw_style_box(_track, Rect2(Vector2.ZERO, size))
	# O preenchimento fica dentro da moldura do trilho.
	var inner := Rect2(Vector2.ZERO, size).grow_individual(-6.0, -6.0, -6.0, -6.0)
	if _trail > ratio:
		_fill.modulate_color = TRAIL_COLOR
		draw_style_box(_fill, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)))
	if ratio > 0.0:
		_fill.modulate_color = LOW_COLOR.lerp(FULL_COLOR, ratio)
		draw_style_box(_fill, Rect2(inner.position, Vector2(maxf(inner.size.x * ratio, 12.0), inner.size.y)))

	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(size.y * 0.7), 10)
	var baseline: float = size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string_outline(font, Vector2(12.0, baseline), "%d" % roundi(health), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24.0, font_size, 4, Color(0.05, 0.05, 0.05, 0.8))
	draw_string(font, Vector2(12.0, baseline), "%d" % roundi(health), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24.0, font_size, Color(1.0, 0.98, 0.94))
