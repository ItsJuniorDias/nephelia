class_name FloorSurfaces
extends RefCounted
## De que é feito o chão num ponto da arena (para o som dos passos).
##
## Os pisos da Sky Plaza são malhas sem colisão (a colisão é uma caixa por plataforma), então o
## raio do chão não diz se é grama ou pedra. O `tools/build_skyplaza.gd` guarda a lista dos pisos
## (retângulo, altura e tipo) como metadado no nó da geometria, que fica no grupo abaixo.

const GROUP: StringName = &"floor_surfaces"
const META: StringName = &"floor_surfaces"
## Tipo de piso -> som dos passos.
const SOUND_OF: Dictionary[String, StringName] = {
	"grass": &"grass", "marble": &"concrete", "asphalt": &"concrete", "sidewalk": &"concrete",
	"wood": &"wood",
}
## Piso só conta se estiver até esta distância abaixo dos pés.
const MAX_DROP: float = 1.2


## Som de passo para quem está em `at` (sem piso conhecido: concreto).
static func footstep_kind(tree: SceneTree, at: Vector3) -> StringName:
	var best_height: float = -INF
	var best_kind: String = ""
	for node: Node in tree.get_nodes_in_group(GROUP):
		var surfaces: Array = node.get_meta(META, [])
		var origin: Vector3 = (node as Node3D).global_position if node is Node3D else Vector3.ZERO
		for surface: Array in surfaces:
			# [tipo, centro, tamanho (x, z)]
			var center: Vector3 = origin + (surface[1] as Vector3)
			var size: Vector2 = surface[2]
			if absf(at.x - center.x) > size.x * 0.5 or absf(at.z - center.z) > size.y * 0.5:
				continue
			if center.y > at.y + 0.3 or center.y < at.y - MAX_DROP:
				continue
			# Pisos se sobrepõem (a calçada do parque em cima da grama): vale o mais alto.
			if center.y >= best_height:
				best_height = center.y
				best_kind = surface[0]
	return SOUND_OF.get(best_kind, &"concrete")
