class_name RailGripModifier
extends SkeletonModifier3D
## Levanta o braço esquerdo até o trilho (pose de "pendurado") por cima da animação.
## A força do efeito é o `influence` (0 = só a animação, 1 = mão no trilho); o braço
## direito continua na pose de mira, então dá para atirar pendurado.

@export var upper_arm_bone: StringName = &"upperarm_l"
@export var lower_arm_bone: StringName = &"lowerarm_l"
@export var hand_bone: StringName = &"hand_l"
## Altura do trilho acima dos pés do personagem (igual a Character.RAIL_HANG).
@export var grip_height: float = 2.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	var upper: int = skeleton.find_bone(upper_arm_bone)
	var lower: int = skeleton.find_bone(lower_arm_bone)
	var hand: int = skeleton.find_bone(hand_bone)
	if upper < 0 or lower < 0 or hand < 0:
		return
	# Cotovelo esticado (como na pose de descanso, que é o "T").
	skeleton.set_bone_pose_rotation(lower, skeleton.get_bone_rest(lower).basis.get_rotation_quaternion())
	# Gira o ombro para a mão apontar para o trilho, logo acima da cabeça.
	var shoulder: Transform3D = skeleton.get_bone_global_pose(upper)
	var hand_position: Vector3 = skeleton.get_bone_global_pose(hand).origin
	var grip_world: Vector3 = skeleton.global_position + Vector3.UP * grip_height
	var grip: Vector3 = skeleton.global_transform.affine_inverse() * grip_world
	var turn := Quaternion((hand_position - shoulder.origin).normalized(), (grip - shoulder.origin).normalized())
	var parent_pose: Transform3D = skeleton.get_bone_global_pose(skeleton.get_bone_parent(upper))
	var local_basis: Basis = parent_pose.basis.inverse() * (Basis(turn) * shoulder.basis)
	skeleton.set_bone_pose_rotation(upper, local_basis.get_rotation_quaternion())
