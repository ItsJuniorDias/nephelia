class_name LegsYawModifier
extends SkeletonModifier3D
## Gira o quadril para o lado em que o personagem anda e destorce o tronco na mesma medida: as
## pernas correm de lado (ou de costas, com a corrida tocada ao contrário) em vez de "patinar"
## com a corrida para a frente, e da cintura para cima ele continua virado para a mira.
## `yaw` em radianos, em volta do eixo vertical do modelo (quem calcula é o CharacterModel).
##
## O efeito de um SkeletonModifier3D é temporário (não dá para ler a pose depois): `torso_error`
## guarda quanto o tronco saiu da pose da animação depois do giro (deve ficar perto de zero).

@export var hips_bone: StringName = &"pelvis"
@export var torso_bone: StringName = &"spine_01"

var yaw: float = 0.0
var torso_error: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	torso_error = 0.0
	if skeleton == null or is_zero_approx(yaw):
		return
	var hips: int = skeleton.find_bone(hips_bone)
	var torso: int = skeleton.find_bone(torso_bone)
	if hips < 0 or torso < 0:
		return
	var turn := Basis(Vector3.UP, yaw)
	var torso_before: Quaternion = skeleton.get_bone_global_pose(torso).basis.get_rotation_quaternion()
	_turn_bone(skeleton, hips, turn)
	_turn_bone(skeleton, torso, turn.inverse())
	torso_error = torso_before.angle_to(skeleton.get_bone_global_pose(torso).basis.get_rotation_quaternion())


# Gira o osso em volta do eixo vertical do esqueleto, no lugar (a origem dele não sai do lugar).
func _turn_bone(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local_basis: Basis = parent_basis.inverse() * (turn * pose.basis)
	skeleton.set_bone_pose_rotation(bone, local_basis.get_rotation_quaternion())
