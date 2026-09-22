class_name BoneFollower
extends Node3D
## Segue um osso do esqueleto (como o BoneAttachment3D, mas em código nosso).
##
## O BoneAttachment3D deixou a arma fora do lugar no iPhone; aqui a posição é copiada do osso a
## cada quadro, com a mesma conta, e dá para conferir em teste.

## Osso que o nó acompanha.
@export var bone_name: StringName = &"hand_r"
## Posição e giro em relação ao osso (o revólver fica na palma, não no pulso).
@export var offset: Transform3D = Transform3D.IDENTITY

var _skeleton: Skeleton3D
var _bone: int = -1


func _ready() -> void:
	_skeleton = get_parent() as Skeleton3D
	if _skeleton != null:
		_bone = _skeleton.find_bone(bone_name)
	# O esqueleto é atualizado na animação, que roda no processo: seguimos depois dela.
	process_priority = 1


func _process(_delta: float) -> void:
	if _skeleton == null or _bone < 0:
		return
	transform = _skeleton.get_bone_global_pose(_bone) * offset
