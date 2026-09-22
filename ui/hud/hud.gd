class_name Hud
extends CanvasLayer
## HUD mínimo do jogador: mira, marcador de acerto e contador de balas.
## (Vida, energia, placar e a arte final entram na tarefa de HUD.)

const HIT_MARKER_TIME: float = 0.15
const HIT_MARKER_COLOR := Color(1.0, 0.95, 0.85)

var weapon: Weapon

var _hit_marker_timer: float = 0.0

@onready var ammo_label: Label = $Root/AmmoLabel
@onready var hit_marker: Control = $Root/HitMarker


func _ready() -> void:
	hit_marker.draw.connect(_draw_hit_marker)
	hit_marker.visible = false


## Chamado pelo HumanController: passa a mostrar a munição desta arma.
func setup(for_weapon: Weapon) -> void:
	weapon = for_weapon
	weapon.ammo_changed.connect(_on_ammo_changed.unbind(2))
	weapon.reload_started.connect(_refresh_ammo)
	weapon.reload_finished.connect(_refresh_ammo)
	weapon.fired.connect(_on_fired)
	_refresh_ammo()


func _process(delta: float) -> void:
	if _hit_marker_timer > 0.0:
		_hit_marker_timer -= delta
		hit_marker.visible = _hit_marker_timer > 0.0


func _refresh_ammo() -> void:
	if weapon.is_reloading:
		ammo_label.text = "RELOAD"
	else:
		ammo_label.text = "%d | %d" % [weapon.ammo, weapon.magazine_size]


func _on_ammo_changed() -> void:
	_refresh_ammo()


func _on_fired(result: ShotResult) -> void:
	_refresh_ammo()
	# Acertou alguém: um "X" rápido na mira (o jogador precisa saber que pegou).
	if result.victim != null:
		_hit_marker_timer = HIT_MARKER_TIME
		hit_marker.visible = true


func _draw_hit_marker() -> void:
	var center: Vector2 = hit_marker.size * 0.5
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		hit_marker.draw_line(center + corner * 7.0, center + corner * 15.0, HIT_MARKER_COLOR, 3.0, true)
