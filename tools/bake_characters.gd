extends SceneTree
## Ferramenta: separa as peças dos personagens que vestimos por cima da roupa.
##   Godot --headless --path . -s res://tools/bake_characters.gd
##
## A roupa (Modular Character Outfits) já traz braços, mãos e pernas; do corpo do Universal
## Base Characters só serve a CABEÇA (o leia-me do pacote avisa: o corpo inteiro atravessa a
## roupa). A versão grátis não tem a cabeça separada, então ela é recortada aqui: ficam os
## triângulos presos aos ossos do pescoço e da cabeça, mais os olhos e as sobrancelhas. Os
## cabelos e a barba só mudam de formato (CharacterPart). Tudo vai para
## `assets/models/characters/parts/`.

const OUT := "res://assets/models/characters/parts/"
const BASE := "res://assets/models/characters/quaternius_ubc/"
const HAIR := "res://assets/models/characters/quaternius_hair/"
## O que fica do corpo (medidas no espaço do esqueleto parado, em metros): a cabeça (vértice
## com pelo menos metade do peso nos ossos da cabeça e do pescoço) e o pescoço dentro de uma
## elipse em volta do eixo dele, até a altura da gola. A borda de baixo vira um TUBO que desce
## para dentro da gola, com o pé preso ao peito (spine_03): o pescoço estica entre a cabeça e o
## tronco como um de verdade. Sem ele a cabeça parecia flutuar (o pescoço terminava na borda da
## gola e, na pose de tiro, ele se inclina e se afasta dela); e o colo do corpo musculoso não
## serve, porque é mais largo que o peito da roupa e fica na frente da camisa.
const HEAD_WEIGHT: float = 0.5
const NECK_CENTER := Vector2(0.0, -0.025)
const NECK_ELLIPSE := Vector2(0.068, 0.1)
const NECK_BOTTOM: float = 1.5
## O tubo desce isto e afina um pouco (fica bem dentro da gola).
const TUBE_DROP: float = 0.1
const TUBE_TAPER: float = 0.85
## A borda que vira tubo fica até esta altura acima do ponto mais baixo do pescoço.
const RING_HEIGHT: float = 0.05
const CHEST_BONE := "spine_03"
const HEAD_BONES: Array[String] = ["neck_01", "Head"]
const HAIRS: Dictionary[String, String] = {
	"hair_buzzed": "Hair_Buzzed", "hair_buzzed_female": "Hair_BuzzedFemale",
	"hair_parted": "Hair_SimpleParted", "hair_long": "Hair_Long", "hair_buns": "Hair_Buns",
	"beard": "Hair_Beard",
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok: bool = true
	ok = _bake_head("head_male", BASE + "Superhero_Male_FullBody.gltf", "SuperHero_Male") and ok
	ok = _bake_head("head_female", BASE + "Superhero_Female_FullBody.gltf", "Superhero_Female") and ok
	for part_name: String in HAIRS:
		ok = _bake_hair(part_name, HAIR + HAIRS[part_name] + ".gltf") and ok
	quit(0 if ok else 1)


func _bake_head(part_name: String, source: String, body_name: String) -> bool:
	var scene: Node = (load(source) as PackedScene).instantiate()
	var skeleton := scene.get_node("Armature/Skeleton3D") as Skeleton3D
	var body := skeleton.get_node(body_name) as MeshInstance3D
	var mesh := ArrayMesh.new()
	# Os ossos da cabeça, na numeração do Skin da malha.
	var head_binds: Array[int] = []
	for bind: int in body.skin.get_bind_count():
		if body.skin.get_bind_name(bind) in HEAD_BONES:
			head_binds.append(bind)
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var chest_bind: int = -1
	for bind: int in body.skin.get_bind_count():
		if body.skin.get_bind_name(bind) == CHEST_BONE:
			chest_bind = bind
	_add_surface(mesh, _keep_head(arrays, head_binds, chest_bind), body.mesh.surface_get_material(0), "Skin")
	# Olhos e sobrancelhas inteiros (são pequenos e só dependem da cabeça).
	for extra: String in ["Eyes", "Eyebrows"]:
		var instance := skeleton.get_node(extra) as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			_add_surface(mesh, instance.mesh.surface_get_arrays(surface),
					instance.mesh.surface_get_material(surface), extra)
	return _save(part_name, mesh, body.skin, scene)


func _bake_hair(part_name: String, source: String) -> bool:
	var scene: Node = (load(source) as PackedScene).instantiate()
	var instance := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	return _save(part_name, instance.mesh, instance.skin, scene)


func _save(part_name: String, mesh: Mesh, skin: Skin, scene: Node) -> bool:
	var part := CharacterPart.new()
	part.mesh = mesh
	part.skin = skin.duplicate()
	var path: String = OUT + part_name + ".res"
	var err: Error = ResourceSaver.save(part, path)
	var box: AABB = mesh.get_aabb()
	print("saved %s (%s): surfaces=%d tris=%d aabb y %.3f..%.3f x %.3f..%.3f z %.3f..%.3f" % [path,
			error_string(err), mesh.get_surface_count(), _triangles(mesh), box.position.y, box.end.y,
			box.position.x, box.end.x, box.position.z, box.end.z])
	scene.free()
	return err == OK


# Cabeça e pescoço, mais o tubo que desce da borda do pescoço para dentro da gola.
func _keep_head(arrays: Array, head_binds: Array[int], chest_bind: int) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var keep := PackedByteArray()
	keep.resize(vertices.size())
	for vertex: int in vertices.size():
		var total: float = 0.0
		for i: int in influences:
			if bones[vertex * influences + i] in head_binds:
				total += weights[vertex * influences + i]
		var point: Vector3 = vertices[vertex]
		var around: Vector2 = (Vector2(point.x, point.z) - NECK_CENTER) / NECK_ELLIPSE
		keep[vertex] = 1 if total >= HEAD_WEIGHT or (point.y >= NECK_BOTTOM and around.length() <= 1.0) else 0

	# Triângulos que ficam (os três vértices dentro) e quantas vezes cada aresta aparece.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var edge_count: Dictionary[Vector2i, int] = {}
	for corner: int in range(0, indices.size(), 3):
		var tri: Array[int] = [indices[corner], indices[corner + 1], indices[corner + 2]]
		if not (keep[tri[0]] and keep[tri[1]] and keep[tri[2]]):
			continue
		kept.append_array(tri)
		for k: int in 3:
			var key := Vector2i(mini(tri[k], tri[(k + 1) % 3]), maxi(tri[k], tri[(k + 1) % 3]))
			edge_count[key] = edge_count.get(key, 0) + 1

	# Borda do pescoço: arestas de um triângulo só, e só as lá de baixo. A malha tem outras
	# bordas (boca, olhos) que também não podem virar tubo.
	var lowest: float = INF
	for vertex: int in kept:
		lowest = minf(lowest, vertices[vertex].y)
	var ring: Array[Vector2i] = []
	for corner: int in range(0, kept.size(), 3):
		for k: int in 3:
			var a: int = kept[corner + k]
			var b: int = kept[corner + (k + 1) % 3]
			if edge_count[Vector2i(mini(a, b), maxi(a, b))] == 1 \
					and vertices[a].y < lowest + RING_HEIGHT and vertices[b].y < lowest + RING_HEIGHT:
				ring.append(Vector2i(a, b))

	# Vértices finais: os que ficaram, renumerados, mais uma cópia de cada vértice da borda
	# lá embaixo, presa ao peito.
	var remap: Dictionary[int, int] = {}
	for vertex: int in kept:
		if not remap.has(vertex):
			remap[vertex] = remap.size()
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	for kind: int in Mesh.ARRAY_MAX:
		if arrays[kind] == null or kind == Mesh.ARRAY_INDEX:
			continue
		result[kind] = _pick(arrays[kind], vertices.size(), remap)
	var new_indices := PackedInt32Array()
	for vertex: int in kept:
		new_indices.append(remap[vertex])
	var dropped: Dictionary[int, int] = {}
	for edge: Vector2i in ring:
		for vertex: int in [edge.x, edge.y]:
			if not dropped.has(vertex):
				dropped[vertex] = _add_dropped(result, arrays, vertex, influences, chest_bind)
		# A aresta aparece como a->b no triângulo de cima: no de baixo, b->a.
		var a: int = remap[edge.x]
		var b: int = remap[edge.y]
		new_indices.append_array([b, a, dropped[edge.x], b, dropped[edge.x], dropped[edge.y]])
	result[Mesh.ARRAY_INDEX] = new_indices
	return result


# Copia o vértice `vertex` para baixo (tubo do pescoço), preso só ao peito. Devolve o índice novo.
func _add_dropped(result: Array, arrays: Array, vertex: int, influences: int, chest_bind: int) -> int:
	var source: Vector3 = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[vertex]
	var around: Vector2 = Vector2(source.x, source.z) - NECK_CENTER
	var tucked: Vector2 = NECK_CENTER + around * TUBE_TAPER
	var positions: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
	var index: int = positions.size()
	positions.append(Vector3(tucked.x, source.y - TUBE_DROP, tucked.y))
	result[Mesh.ARRAY_VERTEX] = positions
	for kind: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if result[kind] == null:
			continue
		var list: Variant = result[kind]
		var stride: int = (arrays[kind] as Variant).size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for i: int in stride:
			list.append(arrays[kind][vertex * stride + i])
		result[kind] = list
	var bone_list: PackedInt32Array = result[Mesh.ARRAY_BONES]
	var weight_list: PackedFloat32Array = result[Mesh.ARRAY_WEIGHTS]
	for i: int in influences:
		bone_list.append(chest_bind if i == 0 else 0)
		weight_list.append(1.0 if i == 0 else 0.0)
	result[Mesh.ARRAY_BONES] = bone_list
	result[Mesh.ARRAY_WEIGHTS] = weight_list
	return index


# Copia, na ordem nova, os dados dos vértices que ficaram (cada tipo tem seu tamanho por vértice).
func _pick(source: Variant, vertex_count: int, remap: Dictionary[int, int]) -> Variant:
	var picked: Variant = source.duplicate()
	var stride: int = source.size() / vertex_count
	picked.resize(remap.size() * stride)
	for old: int in remap:
		for i: int in stride:
			picked[remap[old] * stride + i] = source[old * stride + i]
	return picked


func _add_surface(mesh: ArrayMesh, arrays: Array, material: Material, surface_name: String) -> void:
	# Canais extras (CUSTOM) exigem formato próprio e nenhuma peça usa: saem.
	for kind: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[kind] = null
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface: int = mesh.get_surface_count() - 1
	mesh.surface_set_material(surface, material)
	mesh.surface_set_name(surface, surface_name)


func _triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total
