class_name Pickup
extends Area3D
## Item da arena (frasco de vida, energia, arma): gira no ar, some quando alguém pega e volta
## depois de `respawn_time` segundos.
##
## Quem decide se o personagem pode pegar (e o que ele ganha) é o MatchReferee, como nos
## tiros: o item só avisa "fulano está encostando em mim". No multiplayer só o servidor decide.

signal taken(by: Character)
signal restored

enum Kind { HEALTH, ENERGY, RIFLE, SHOTGUN }

const GROUP: StringName = &"pickups"
## Altura do item acima do chão (e quanto ele sobe e desce flutuando).
const FLOAT_HEIGHT: float = 0.7
const BOB_HEIGHT: float = 0.08
const SPIN_SPEED: float = 1.6

@export var kind: Kind = Kind.HEALTH
## Quanto o item dá (vida, energia ou munição, conforme o tipo).
@export var amount: float = 50.0
@export_range(1.0, 120.0, 1.0, "suffix:s") var respawn_time: float = 20.0

var is_available: bool = true

var _respawn_timer: float = 0.0
var _time: float = 0.0
var _visual: Node3D
var _glow: MeshInstance3D

@onready var _sound: AudioStreamPlayer3D = $PickupSound


func _ready() -> void:
	add_to_group(GROUP)
	_sound.bus = Sounds.SFX_BUS
	# Cada item começa num ponto diferente do giro (não ficam todos sincronizados).
	_time = fmod(absf(global_position.x * 1.3 + global_position.z * 0.7), TAU)
	_visual = PickupVisuals.build(kind)
	add_child(_visual)
	_glow = PickupVisuals.build_glow(kind)
	add_child(_glow)


func _physics_process(delta: float) -> void:
	if not is_available:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			restore()
		return
	# Confere a cada passo (e não só ao entrar): quem já estava em cima e se machucou também pega.
	var referee: MatchReferee = MatchReferee.find(self)
	if referee == null:
		return
	for body: Node3D in get_overlapping_bodies():
		var character := body as Character
		if character != null and referee.try_pickup(character, self):
			return


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y = _time * SPIN_SPEED
	_visual.position.y = FLOAT_HEIGHT + sin(_time * 3.0) * BOB_HEIGHT


## Nome da arma que este item dá ("" se o item não for arma).
static func weapon_id_of(of_kind: Kind) -> StringName:
	match of_kind:
		Kind.RIFLE:
			return &"repeater"
		Kind.SHOTGUN:
			return &"shotgun"
	return &""


## Texto curto do HUD para quem pegou (ex.: "+50 HP", "REPEATER").
func get_hud_text() -> String:
	match kind:
		Kind.HEALTH:
			return "+%d HP" % roundi(amount)
		Kind.ENERGY:
			return "+%d ENERGY" % roundi(amount)
	var weapon: WeaponData = WeaponCatalog.get_weapon(weapon_id_of(kind))
	return weapon.weapon_name.to_upper() if weapon != null else ""


## O juiz confirmou: some e começa a contar o tempo para voltar.
func take(by: Character) -> void:
	is_available = false
	_respawn_timer = respawn_time
	_visual.visible = false
	_glow.visible = false
	_sound.play()
	taken.emit(by)


## Volta a aparecer (fim do tempo ou reinício da partida).
func restore() -> void:
	is_available = true
	_respawn_timer = 0.0
	_visual.visible = true
	_glow.visible = true
	_visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_visual, ^"scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	restored.emit()
