class_name HiddenBonesModifier
extends SkeletonModifier3D
## Encolhe até sumir os ossos listados (e tudo que está preso neles).
##
## Serve para a visão em primeira pessoa: o jogador vê os próprios braços com a arma, mas não a
## cabeça nem as pernas, que ficariam atravessando a câmera.

## Escala mínima em vez de zero: zero deixaria as normais inválidas (pontos pretos).
const TINY: float = 0.001

@export var bones: Array[StringName] = [&"Head", &"thigh_l", &"thigh_r"]


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for bone_name: StringName in bones:
		var bone: int = skeleton.find_bone(bone_name)
		if bone >= 0:
			skeleton.set_bone_pose_scale(bone, Vector3.ONE * TINY)
