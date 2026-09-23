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

## Ponto em volta do qual a arma apoiada gira para a mira: o ombro, onde a coronha se apoia
## (WeaponCatalog.SHOULDER_POCKET), na pose de mira parada. Conferir o alcance da mão esquerda de
## -85° a +85° (teste I9) e as fotos do `tools/pose_sheet.gd` (mira para cima e para baixo).
const CHEST_PIVOT := Vector3(-0.14, 1.37, -0.13)
## A arma apoiada acompanha o peito: o quanto este osso se moveu desde a pose de mira parada
## (CHEST_NEUTRAL, medida com o bot parado mirando reto). Mirando para cima o tronco se inclina
## 48° para trás e o ombro recua 12 cm: com a arma parada no corpo, a coronha saía do ombro e a mão
## esquerda não alcançava a telha. Correndo, a arma balança junto com o peito.
const CHEST_BONE: StringName = &"spine_03"
const CHEST_NEUTRAL := Transform3D(
		Basis(Vector3(0.7907, -0.0779, 0.6073), Vector3(-0.0246, 0.987, 0.1586), Vector3(-0.6118, -0.1404, 0.7785)),
		Vector3(0.0033, 1.2386, -0.0694))
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
## A arma apoiada acompanha o peito (ver CHEST_BONE). Em 1ª pessoa não: lá a câmera é que mira.
@export var follow_chest: bool = true

## Para onde o personagem está mirando (radianos, + = para cima). Só vale para a arma apoiada:
## em 1ª pessoa a câmera já se inclina, então lá isto fica zerado.
var aim_pitch: float = 0.0

var _skeleton: Skeleton3D
var _bone: int = -1
var _chest: int = -1
var _neutral_inverse: Transform3D = CHEST_NEUTRAL.orthonormalized().affine_inverse()
## Atualizado pelo WeaponMountSync (etapa do esqueleto); sem ele, no `_process`.
var _synced: bool = false
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
	_chest = _skeleton.find_bone(CHEST_BONE) if _skeleton != null else -1


func _process(delta: float) -> void:
	if not _synced:
		sync(delta)


## Põe a arma no lugar deste quadro (chamado pelo WeaponMountSync, na etapa do esqueleto).
func sync(delta: float) -> void:
	_synced = true
	if _skeleton == null:
		return
	if _bone >= 0:
		transform = _skeleton.get_bone_global_pose(_bone) * offset
		return
	# Apoiada no corpo: vai junto com o peito e gira em volta do ombro o que falta para o cano
	# apontar para a mira.
	var body := Transform3D.IDENTITY
	if follow_chest and _chest >= 0:
		body = _skeleton.get_bone_global_pose(_chest).orthonormalized() * _neutral_inverse
	var barrel: Vector3 = offset.basis * Vector3.FORWARD
	var goal: Vector3 = Basis(Vector3.RIGHT, -aim_pitch) * barrel
	var fix := Quaternion((body.basis * barrel).normalized(), goal.normalized())
	var pivot: Vector3 = body * CHEST_PIVOT
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-KICK_RECOVER_SPEED * delta))
	transform = Transform3D(Basis(fix), pivot) * Transform3D(Basis.IDENTITY, -pivot) * body * offset * _motion()


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
