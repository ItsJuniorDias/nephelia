class_name Hud
extends CanvasLayer
## HUD do jogador: mira, marcador de acerto, munição, vida, proteção de nascimento, aviso de
## dano (borda vermelha + direção do tiro), item pego e tela de eliminado.
## (A arte final e o placar entram na tarefa de HUD.)

const HIT_MARKER_TIME: float = 0.15
const HIT_MARKER_COLOR := Color(1.0, 0.95, 0.85)
const LOW_HEALTH: float = 35.0
const HEALTH_COLOR := Color(1.0, 0.97, 0.9)
const LOW_HEALTH_COLOR := Color(1.0, 0.35, 0.3)
## Quanto tempo a seta de "levei tiro daqui" fica na tela.
const DAMAGE_DIRECTION_TIME: float = 1.2
const DAMAGE_DIRECTION_RADIUS: float = 110.0
const DAMAGE_COLOR := Color(0.95, 0.15, 0.1)

var character: Character
var weapon: Weapon

var _hit_marker_timer: float = 0.0
var _vignette_alpha: float = 0.0
var _last_health: float = 0.0
## De onde vieram os tiros recentes: [{"from": Vector3, "time": float}].
var _damage_sources: Array[Dictionary] = []
var _death_title: String = ""
var _respawn_countdown: float = 0.0
var _pickup_tween: Tween

@onready var crosshair: TextureRect = $Root/Crosshair
@onready var ammo_pips: AmmoPips = $Root/AmmoPips
@onready var health_bar: HealthBar = $Root/HealthBar
@onready var protection_label: Label = $Root/ProtectionLabel
@onready var rail_hint: Label = $Root/RailHint
@onready var pickup_label: Label = $Root/PickupLabel
@onready var hit_marker: Control = $Root/HitMarker
@onready var damage_vignette: TextureRect = $Root/DamageVignette
@onready var damage_directions: Control = $Root/DamageDirections
@onready var death_panel: Control = $Root/DeathPanel
@onready var death_label: Label = $Root/DeathPanel/DeathLabel


func _ready() -> void:
	hit_marker.draw.connect(_draw_hit_marker)
	damage_directions.draw.connect(_draw_damage_directions)
	hit_marker.visible = false
	death_panel.visible = false
	protection_label.visible = false
	damage_vignette.modulate.a = 0.0


## Chamado pelo HumanController: passa a mostrar a vida e a munição deste personagem.
func setup(for_character: Character) -> void:
	character = for_character
	weapon = character.weapon
	character.health_changed.connect(_on_health_changed)
	character.hit_received.connect(_on_hit_received)
	character.died.connect(_on_died)
	character.respawned.connect(_on_respawned)
	character.picked_up.connect(_on_picked_up)
	_last_health = character.health
	_on_health_changed(character.health, character.max_health)
	if weapon != null:
		weapon.ammo_changed.connect(_on_ammo_changed.unbind(2))
		weapon.reload_started.connect(_refresh_ammo)
		weapon.reload_finished.connect(_refresh_ammo)
		weapon.fired.connect(_on_fired)
		_refresh_ammo()


func _process(delta: float) -> void:
	if weapon != null and weapon.is_reloading:
		_refresh_ammo()
	if _hit_marker_timer > 0.0:
		_hit_marker_timer -= delta
		hit_marker.visible = _hit_marker_timer > 0.0

	_vignette_alpha = move_toward(_vignette_alpha, 0.0, delta * 1.2)
	damage_vignette.modulate.a = _vignette_alpha

	if not _damage_sources.is_empty():
		for source: Dictionary in _damage_sources:
			source["time"] -= delta
		_damage_sources = _damage_sources.filter(func(source: Dictionary) -> bool: return source["time"] > 0.0)
		damage_directions.queue_redraw()

	if character != null:
		protection_label.visible = character.is_alive and character.is_spawn_protected

	if death_panel.visible:
		_respawn_countdown = maxf(_respawn_countdown - delta, 0.0)
		death_label.text = "%s\n\nRespawn in %d" % [_death_title, ceili(_respawn_countdown)]


## Mostra por um instante o que o jogador pegou (ex.: "+50 HP"), da cor do item.
func show_pickup(text: String, color: Color) -> void:
	pickup_label.text = text
	pickup_label.add_theme_color_override(&"font_color", color.lightened(0.35))
	pickup_label.visible = true
	pickup_label.modulate.a = 1.0
	if _pickup_tween != null:
		_pickup_tween.kill()
	_pickup_tween = pickup_label.create_tween()
	_pickup_tween.tween_interval(1.0)
	_pickup_tween.tween_property(pickup_label, ^"modulate:a", 0.0, 0.5)
	_pickup_tween.tween_callback(pickup_label.hide)


func _on_picked_up(pickup: Pickup) -> void:
	show_pickup(pickup.get_hud_text(), PickupVisuals.color_of(pickup.kind))


## Mostra "HOOK" embaixo da mira quando há um trilho ao alcance.
func set_rail_hint(shown: bool) -> void:
	rail_hint.visible = shown


## Ângulos (graus) de onde vieram os tiros recentes: 0 = frente, positivo = direita.
func get_damage_angles() -> Array[float]:
	var angles: Array[float] = []
	for source: Dictionary in _damage_sources:
		angles.append(rad_to_deg(_damage_angle(source["from"])))
	return angles


func _refresh_ammo() -> void:
	ammo_pips.show_ammo(weapon.ammo, weapon.magazine_size, weapon.is_reloading, weapon.get_reload_progress())


func _on_ammo_changed() -> void:
	_refresh_ammo()


func _on_fired(result: ShotResult) -> void:
	_refresh_ammo()
	# Causou dano em alguém: um "X" rápido na mira (o jogador precisa saber que pegou).
	if result.victim != null and result.damage > 0.0:
		_hit_marker_timer = HIT_MARKER_TIME
		hit_marker.visible = true


func _on_health_changed(health: float, max_health: float) -> void:
	health_bar.set_health(health, max_health)
	# Perdeu vida: borda vermelha, mais forte quanto maior o dano.
	if health < _last_health:
		_vignette_alpha = clampf(_vignette_alpha + 0.2 + (_last_health - health) / 150.0, 0.0, 0.6)
	_last_health = health


func _on_hit_received(result: ShotResult) -> void:
	if result.damage > 0.0 and result.shooter != null:
		_damage_sources.append({"from": result.shooter.global_position, "time": DAMAGE_DIRECTION_TIME})
		damage_directions.queue_redraw()


func _on_died(killer: Character) -> void:
	_death_title = "ELIMINATED\nby %s" % killer.display_name if killer != null else "ELIMINATED\nfell off the island"
	var referee: MatchReferee = MatchReferee.find(self)
	_respawn_countdown = referee.respawn_delay if referee != null else 0.0
	death_panel.visible = true
	crosshair.visible = false
	_damage_sources.clear()
	damage_directions.queue_redraw()


func _on_respawned() -> void:
	death_panel.visible = false
	crosshair.visible = true
	_vignette_alpha = 0.0
	_last_health = character.health


# 0 = frente do jogador, positivo = direita (recalculado a cada quadro: acompanha o giro).
func _damage_angle(from: Vector3) -> float:
	var local: Vector3 = character.global_transform.basis.inverse() * (from - character.global_position)
	return atan2(local.x, -local.z)


func _draw_damage_directions() -> void:
	var center: Vector2 = damage_directions.size * 0.5
	for source: Dictionary in _damage_sources:
		# Na tela, ângulo 0 aponta para a direita; "frente" do jogador é para cima.
		var screen_angle: float = _damage_angle(source["from"]) - PI / 2.0
		var alpha: float = clampf(source["time"] / DAMAGE_DIRECTION_TIME, 0.0, 1.0)
		damage_directions.draw_arc(center, DAMAGE_DIRECTION_RADIUS, screen_angle - 0.35, screen_angle + 0.35,
				20, Color(DAMAGE_COLOR, alpha), 8.0, true)


func _draw_hit_marker() -> void:
	var center: Vector2 = hit_marker.size * 0.5
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		hit_marker.draw_line(center + corner * 7.0, center + corner * 15.0, HIT_MARKER_COLOR, 3.0, true)
