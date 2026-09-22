class_name GunMount
extends RefCounted
## Monta o revólver na mão direita de um esqueleto, em código.
##
## Antes a arma era um nó guardado dentro da cena do modelo (filho de um nó que segue o osso).
## No build do iPhone esses nós não existiam e ninguém aparecia armado, embora no Mac
## funcionasse. Criando na hora, a montagem é a mesma para o corpo e para a 1ª pessoa e não
## depende de nós salvos dentro de uma cena instanciada.

const MESH: Mesh = preload("res://assets/models/weapons/colt_revolver.res")
## Posição e giro do revólver na palma da mão (medidos no modelo). Atenção: no arquivo de cena
## a matriz é escrita por LINHAS e aqui por COLUNAS (uma é a transposta da outra).
const IN_HAND := Transform3D(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(0, 0.18, -0.05))
## Ponta do cano, no espaço do revólver (de onde sai o rastro do tiro).
const BARREL_TIP := Vector3(0.0005, 0.1477, -0.19)


## Cria o suporte que segue o osso e o revólver nele; devolve o nó do revólver.
static func attach(skeleton: Skeleton3D, bone: StringName = &"hand_r") -> MeshInstance3D:
	var follower := BoneFollower.new()
	follower.name = "RightHand"
	follower.bone_name = bone
	skeleton.add_child(follower)
	var gun := MeshInstance3D.new()
	gun.name = "Gun"
	gun.mesh = MESH
	gun.transform = IN_HAND
	follower.add_child(gun)
	return gun
