class_name WeaponMount
extends Node3D
## Onde a arma fica no corpo: presa ao osso da mão (revólver) ou apoiada na frente do peito,
## acompanhando a mira (armas longas, seguradas com as duas mãos).
##
## Substitui o BoneAttachment3D, que deixou a arma fora do lugar no iPhone: a posição é copiada
## do osso a cada quadro, com a mesma conta, e dá para conferir em teste.
##
## As animações são de pistola: nas armas longas o coice e a recarga são feitos aqui, mexendo a
## própria arma — as mãos vão junto, porque a IK as leva até ela.

## Ponto em volta do qual a arma apoiada sobe e desce com a mira: no meio do tronco, um pouco
## atrás. Mais alto (no peito), a mão esquerda não alcançava a telha mirando para cima (medido de
## -80° a +80° com a pose de mira do tronco).
const CHEST_PIVOT := Vector3(0.0, 1.25, -0.1)
## Coice da arma longa (com `WeaponData.recoil` = 1): recua e levanta o cano.
const KICK_BACK: float = 0.05
const KICK_PITCH_DEGREES: float = 7.0
const KICK_RECOVER_SPEED: float = 10.0

## Osso seguido. Vazio = a arma fica apoiada no corpo (e não na mão).
@export var bone_name: StringName = &"hand_r"
## Posição e giro em relação ao osso (ou ao corpo, quando não segue osso nenhum).
@export var offset: Transform3D = Transform3D.IDENTITY
## Mostra o coice aqui. Em 1ª pessoa quem faz o coice é o ViewModel (os braços inteiros).
@export var animate_kick: bool = true

## Para onde o personagem está mirando (radianos, + = para cima). Só vale para a arma apoiada:
## em 1ª pessoa a câmera já se inclina, então lá isto fica zerado.
var aim_pitch: float = 0.0

var _skeleton: Skeleton3D
var _bone: int = -1
var _weapon: Weapon
var _kick: float = 0.0
## Ponto da arma (entre as duas mãos) em volta do qual ela gira no coice e na recarga.
var _motion_pivot := Vector3.ZERO


func _ready() -> void:
	_skeleton = get_parent() as Skeleton3D
	_find_bone()
	# O esqueleto é atualizado na animação, que roda no processo: seguimos depois dela.
	process_priority = 1


## Passa a seguir outro osso, noutro lugar (o revólver fica na mão, o rifle apoiado no peito).
func follow(new_bone: StringName, new_offset: Transform3D, motion_pivot: Vector3 = Vector3.ZERO) -> void:
	bone_name = new_bone
	offset = new_offset
	_motion_pivot = motion_pivot
	_kick = 0.0
	_find_bone()


## Acompanha os tiros e a recarga desta arma (coice e movimento de recarga das armas longas).
func watch(weapon: Weapon) -> void:
	if _weapon != null and _weapon.fired.is_connected(_on_fired):
		_weapon.fired.disconnect(_on_fired)
	_weapon = weapon
	if _weapon != null:
		_weapon.fired.connect(_on_fired)


func _find_bone() -> void:
	_bone = _skeleton.find_bone(bone_name) if _skeleton != null and not bone_name.is_empty() else -1


func _process(delta: float) -> void:
	if _skeleton == null:
		return
	if _bone >= 0:
		transform = _skeleton.get_bone_global_pose(_bone) * offset
		return
	# Apoiada no corpo: sobe e desce em volta do peito, conforme a mira.
	var tilt := Transform3D(Basis(Vector3.RIGHT, -aim_pitch), CHEST_PIVOT) \
			* Transform3D(Basis.IDENTITY, -CHEST_PIVOT)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-KICK_RECOVER_SPEED * delta))
	transform = tilt * offset * _motion()


# Coice e recarga, no espaço da arma (+Y para cima, cano para -Z), girando entre as mãos.
func _motion() -> Transform3D:
	var data: WeaponData = _weapon.data if _weapon != null else null
	if data == null:
		return Transform3D.IDENTITY
	var kick: float = _kick * data.recoil if animate_kick else 0.0
	# Recarga: vai e volta (0 no começo, máximo no meio, 0 no fim).
	var reload: float = sin(PI * _weapon.get_reload_progress()) if _weapon.is_reloading else 0.0
	var turn: Basis = Basis(Vector3.RIGHT, deg_to_rad(KICK_PITCH_DEGREES * kick + data.reload_motion.x * reload)) \
			* Basis(Vector3.BACK, deg_to_rad(data.reload_motion.y * reload))
	var shift := Vector3(0.0, -data.reload_motion.z * reload, KICK_BACK * kick)
	return Transform3D(turn, _motion_pivot + shift) * Transform3D(Basis.IDENTITY, -_motion_pivot)


func _on_fired(_result: ShotResult) -> void:
	_kick = 1.0
