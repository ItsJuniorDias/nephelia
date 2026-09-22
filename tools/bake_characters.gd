extends SceneTree
## Ferramenta: prepara as peças dos personagens que vão com a roupa.
##   Godot --headless --path . -s res://tools/bake_characters.gd
##
## CORPO: a cabeça e o pescoço são os do corpo original do Universal Base Characters, intactos
## (pedido do usuário: a cabeça recortada e o pescoço fabricado ficaram estranhos). Do tronco
## fica só a pele que aparece no decote ou fica logo debaixo do tecido; braços, mãos e pernas vêm
## da roupa (o leia-me dela avisa que o corpo inteiro atravessa o tecido).
##
## O pulo do gato é a TRANSFERÊNCIA DE PESOS: o corpo musculoso e a camisa dobram diferente nas
## animações (em repouso a pele fica debaixo do tecido; na pose de tiro ela escapava por cima dos
## ombros ou abria vão na gola). Então a pele do tronco passa a dobrar com os mesmos ossos e pesos
## do ponto da roupa mais perto dela; a cabeça e o pescoço guardam os pesos originais, e a pele
## entre os dois estica como um pescoço de verdade. O que está escondido em repouso fica escondido
## em qualquer pose.
##
## Tudo é feito no esqueleto da ROUPA (que é o que o jogo usa): os vértices são levados para a
## pose de descanso dele e a ligação aos ossos (Skin) passa a ser a dele.
##
## CABELOS e BARBA: só mudam de formato (CharacterPart). Tudo vai para
## `assets/models/characters/parts/`.

const OUT := "res://assets/models/characters/parts/"
const BASE := "res://assets/models/characters/quaternius_ubc/"
const HAIR := "res://assets/models/characters/quaternius_hair/"
const OUTFITS := "res://assets/models/characters/quaternius_outfits/"
const BODIES: Array[Dictionary] = [
	{"part": "body_male", "source": BASE + "Superhero_Male_FullBody.gltf", "mesh": "SuperHero_Male",
			"outfit": OUTFITS + "Male_Peasant.gltf"},
	{"part": "body_female", "source": BASE + "Superhero_Female_FullBody.gltf", "mesh": "Superhero_Female",
			"outfit": OUTFITS + "Female_Peasant.gltf"},
]
const HEAD_BONES: Array[String] = ["neck_01", "Head"]
const ARM_BONES: Array[String] = ["upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb"]
## Vértice com pelo menos este peso no osso da cabeça: sempre fica, com os pesos originais.
const HEAD_WEIGHT: float = 0.5
## Tecido colado para fora da pele (até REACH_OUT) = pele debaixo da roupa: fica (escondida,
## liga a cabeça ao corpo). Tecido para dentro (até REACH_IN) = pele por fora da roupa: sai.
const REACH_OUT: float = 0.03
const REACH_IN: float = 0.02
## Pele do decote só fica se não houver tecido na frente dela até esta distância (o corpete
## fechado da mulher cobre o peito; lá a pele só atrapalha).
const COVERED_REACH: float = 0.15
## O teste "tem tecido na frente?" só vale no peito (debaixo do queixo a pele aponta para baixo
## e sempre bateria no corpete).
const CHEST_TOP: float = 1.47
## Nas poses o raio para dentro é curto: mais longo, um ponto do pescoço lá dentro da gola
## atravessava o pescoço e batia no outro lado da gola (e saía por engano, abrindo um vão).
const POSE_REACH_IN: float = 0.02
## Tecido a menos disto é a pele ENCOSTADA na roupa (não furando): fica.
const TOUCHING: float = 0.004
## Fora a cabeça, só fica a pele da COLUNA DO PESCOÇO (uma elipse em volta do eixo dele) e, na
## frente, a do DECOTE. A encosta do trapézio do corpo musculoso (abas dos lados do pescoço) e o
## peito debaixo do corpete sobravam e apareciam por cima da roupa nas poses.
const NECK_CENTER := Vector2(0.0, -0.025)
const NECK_RADII := Vector2(0.098, 0.105)
const NECKLINE_HALF_WIDTH: float = 0.075
## Abaixo disto nada do corpo fica: a camisa e o corpete cobrem (sobravam retalhos soltos).
const NECKLINE_BOTTOM: float = 1.36
const MAX_INFLUENCES: int = 4
## A cabeça desce isto (pedido do usuário: "uns 32 px" nas fotos de rosto, ≈ 8 cm). Rosto,
## olhos, cabelo e barba descem inteiros; o pescoço encolhe entre o fundo da gola e o queixo
## (NECK_SQUASH abaixo do osso da cabeça) e o decote fica onde está.
const HEAD_DROP: float = 0.08
const NECK_SQUASH: float = 0.2
## Poses das animações do jogo em que a pele não pode escapar da roupa: [animação, instante (0 a 1)].
## Na pose parada a pele fica debaixo do tecido, mas na pose de tiro o tronco dobra diferente.
## ("Levar tiro" fica de fora: é um tranco rápido, e nele o pescoço inteiro encosta na gola.)
const ANIMATIONS: AnimationLibrary = preload("res://assets/animations/quaternius_ual/character_animations.res")
const CHECK_POSES: Array[Array] = [
	[&"Pistol_Aim_Neutral", 0.0], [&"Pistol_Aim_Up", 0.0], [&"Pistol_Aim_Down", 0.0],
	[&"Pistol_Idle", 0.0], [&"Pistol_Idle", 0.5], [&"Pistol_Shoot", 0.3], [&"Pistol_Reload", 0.3],
	[&"Pistol_Reload", 0.6], [&"Idle", 0.0], [&"Jog_Fwd", 0.3],
]
const HAIRS: Dictionary[String, String] = {
	"hair_buzzed": "Hair_Buzzed", "hair_buzzed_female": "Hair_BuzzedFemale",
	"hair_parted": "Hair_SimpleParted", "hair_long": "Hair_Long", "hair_buns": "Hair_Buns",
	"beard": "Hair_Beard",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok: bool = true
	for spec: Dictionary in BODIES:
		ok = await _bake_body(spec) and ok
	for part_name: String in HAIRS:
		ok = _bake_hair(part_name, HAIR + HAIRS[part_name] + ".gltf") and ok
	quit(0 if ok else 1)


func _bake_body(spec: Dictionary) -> bool:
	var outfit: Node = (load(spec["outfit"]) as PackedScene).instantiate()
	var outfit_skeleton := outfit.get_node("Armature/Skeleton3D") as Skeleton3D
	var cloth: StaticBody3D = _cloth_body(outfit_skeleton)
	root.add_child(cloth)
	for i in 3:
		await physics_frame
	var cloth_points: Dictionary = _cloth_points(outfit_skeleton)

	var scene: Node = (load(spec["source"]) as PackedScene).instantiate()
	var skeleton := scene.get_node("Armature/Skeleton3D") as Skeleton3D
	var body := skeleton.get_node(spec["mesh"]) as MeshInstance3D
	var skin: Skin = body.skin
	# Skin novo: os mesmos ossos, na pose de descanso do esqueleto da roupa.
	var outfit_skin := Skin.new()
	for bind: int in skin.get_bind_count():
		var bone: int = outfit_skeleton.find_bone(skin.get_bind_name(bind))
		outfit_skin.add_named_bind(skin.get_bind_name(bind), outfit_skeleton.get_bone_global_rest(bone).affine_inverse())

	var posed: Array = _to_outfit_space(body.mesh.surface_get_arrays(0), skin, outfit_skeleton)
	var head_y: float = outfit_skeleton.get_bone_global_rest(outfit_skeleton.find_bone("Head")).origin.y
	_lower_head(posed, head_y)
	var under := PackedByteArray()
	var inside: PackedFloat32Array = _choose(posed, skin, cloth.get_world_3d(), under)
	# Para as poses e os pesos: fica quem está dentro, e também o vizinho de fora de um triângulo
	# que vai ser cortado (é dele que sai o vértice novo da borda).
	var keep: PackedByteArray = _near_inside(posed, inside)
	_transfer_weights(posed, keep, under, skin, cloth_points)
	await _drop_poking_in_poses(posed, keep, _head_mask(posed, skin), outfit_skin, outfit)
	for vertex: int in keep.size():
		if not keep[vertex]:
			inside[vertex] = minf(inside[vertex], -1.0)
	var mesh := ArrayMesh.new()
	_add_surface(mesh, _clip(posed, inside), body.mesh.surface_get_material(0), "Skin")
	# Olhos e sobrancelhas originais, inteiros (só levados para o esqueleto da roupa).
	for extra: String in ["Eyes", "Eyebrows"]:
		var instance := skeleton.get_node(extra) as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			var extra_arrays: Array = _to_outfit_space(instance.mesh.surface_get_arrays(surface),
					instance.skin, outfit_skeleton)
			_lower_head(extra_arrays, head_y)
			_rebind(extra_arrays, instance.skin, skin)
			_add_surface(mesh, extra_arrays, instance.mesh.surface_get_material(surface), extra)
	var head_box: AABB = _head_box(posed, skin)
	cloth.queue_free()
	outfit.free()
	var kept: int = 0
	for value: float in inside:
		kept += 1 if value >= 0.0 else 0
	print("%s: %d de %d vértices do corpo ficam" % [spec["part"], kept, keep.size()])
	return _save(spec["part"], mesh, outfit_skin, scene, head_box)


# Cabelo e barba descem junto com a cabeça (inteiros).
func _bake_hair(part_name: String, source: String) -> bool:
	var scene: Node = (load(source) as PackedScene).instantiate()
	var instance := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := ArrayMesh.new()
	for surface: int in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: int in vertices.size():
			vertices[vertex].y -= HEAD_DROP
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_add_surface(mesh, arrays, instance.mesh.surface_get_material(surface), instance.mesh.surface_get_name(surface))
	return _save(part_name, mesh, instance.skin.duplicate(), scene, AABB())


# Desce a cabeça HEAD_DROP: tudo acima do queixo desce inteiro; entre o fundo da gola e o queixo
# o pescoço encolhe aos poucos; abaixo disso nada muda.
func _lower_head(arrays: Array, head_y: float) -> void:
	var top: float = head_y - 0.02
	var bottom: float = top - NECK_SQUASH
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex: int in vertices.size():
		var amount: float = clampf((vertices[vertex].y - bottom) / (top - bottom), 0.0, 1.0)
		vertices[vertex].y -= HEAD_DROP * smoothstep(0.0, 1.0, amount)
	arrays[Mesh.ARRAY_VERTEX] = vertices


func _save(part_name: String, mesh: Mesh, skin: Skin, scene: Node, head_box: AABB) -> bool:
	var part := CharacterPart.new()
	part.mesh = mesh
	part.skin = skin
	part.head_box = head_box
	var path: String = OUT + part_name + ".res"
	var err: Error = ResourceSaver.save(part, path)
	var box: AABB = mesh.get_aabb()
	print("saved %s (%s): surfaces=%d tris=%d aabb y %.3f..%.3f" % [path, error_string(err),
			mesh.get_surface_count(), _triangles(mesh), box.position.y, box.end.y])
	scene.free()
	return err == OK


# ---------------------------------------------------------------- roupa

# A roupa inteira como um corpo de colisão (todas as peças, na pose de descanso).
func _cloth_body(outfit_skeleton: Skeleton3D) -> StaticBody3D:
	var faces := PackedVector3Array()
	for instance: MeshInstance3D in _cloth_meshes(outfit_skeleton):
		for surface: int in instance.mesh.get_surface_count():
			var surface_arrays: Array = instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
			for index: int in surface_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
				faces.append(points[index])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.add_child(collision)
	return body


# Pontos da roupa com os pesos deles (por NOME de osso): {"points": [...], "weights": [{nome: peso}]}.
# Os vértices da roupa já estão na pose de descanso do esqueleto dela.
func _cloth_points(outfit_skeleton: Skeleton3D) -> Dictionary:
	var points := PackedVector3Array()
	var weight_list: Array[Dictionary] = []
	for instance: MeshInstance3D in _cloth_meshes(outfit_skeleton):
		for surface: int in instance.mesh.get_surface_count():
			var surface_arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = surface_arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = surface_arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = bones.size() / vertices.size()
			for vertex: int in vertices.size():
				var named: Dictionary[String, float] = {}
				for i: int in influences:
					var weight: float = weights[vertex * influences + i]
					if weight > 0.0:
						var bone_name: String = instance.skin.get_bind_name(bones[vertex * influences + i])
						named[bone_name] = named.get(bone_name, 0.0) + weight
				points.append(vertices[vertex])
				weight_list.append(named)
	return {"points": points, "weights": weight_list}


func _cloth_meshes(outfit_skeleton: Skeleton3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in outfit_skeleton.get_children():
		if node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)
	return meshes


# ---------------------------------------------------------------- poses

# Tira a pele que escapa da roupa em alguma das CHECK_POSES (a cabeça nunca sai).
func _drop_poking_in_poses(posed: Array, keep: PackedByteArray, head: PackedByteArray, body_skin: Skin,
		outfit: Node) -> void:
	root.add_child(outfit)
	var skeleton := outfit.get_node("Armature/Skeleton3D") as Skeleton3D
	var player := AnimationPlayer.new()
	outfit.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"", ANIMATIONS)
	var dropped: int = 0
	for check: Array in CHECK_POSES:
		var animation: StringName = check[0]
		player.play(animation)
		player.seek(ANIMATIONS.get_animation(animation).length * float(check[1]), true)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_posed_cloth_faces(skeleton))
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		for i in 2:
			await physics_frame
		var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
		var points: Array = _skin_posed(posed, body_skin, skeleton)
		var positions: PackedVector3Array = points[0]
		var normals: PackedVector3Array = points[1]
		for vertex: int in positions.size():
			if not keep[vertex] or head[vertex]:
				continue
			var point: Vector3 = positions[vertex]
			var hit: Dictionary = space.intersect_ray(
					PhysicsRayQueryParameters3D.create(point, point - normals[vertex] * POSE_REACH_IN))
			if not hit.is_empty() and point.distance_to(hit["position"]) > TOUCHING:
				keep[vertex] = 0
				dropped += 1
		body.queue_free()
		await physics_frame
	player.queue_free()
	root.remove_child(outfit)
	print("  poses: %d vértices escapavam da roupa em alguma animação e saíram" % dropped)


# 1 = vértice que nunca sai nas poses: a cabeça e a parte de cima do pescoço, dentro da coluna
# (mirando para baixo o queixo chega perto da gola alta, e a pele sob ele saía, abrindo um furo).
func _head_mask(posed: Array, skin: Skin) -> PackedByteArray:
	var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
	var mask := PackedByteArray()
	mask.resize(vertices.size())
	for vertex: int in vertices.size():
		var point: Vector3 = vertices[vertex]
		var in_column: bool = ((Vector2(point.x, point.z) - NECK_CENTER) / NECK_RADII).length() <= 1.0
		var head: bool = _weight_on(posed, skin, vertex, ["Head"], false) >= HEAD_WEIGHT
		var upper_neck: bool = in_column and _weight_on(posed, skin, vertex, HEAD_BONES, false) >= HEAD_WEIGHT
		mask[vertex] = 1 if head or upper_neck else 0
	return mask


# Faces da roupa na pose atual do esqueleto.
func _posed_cloth_faces(skeleton: Skeleton3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for instance: MeshInstance3D in _cloth_meshes(skeleton):
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var posed_points: PackedVector3Array = _skin_posed(arrays, instance.skin, skeleton)[0]
			for index: int in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
				faces.append(posed_points[index])
	return faces


# Posições e normais dos vértices na pose atual do esqueleto (a mesma conta da placa de vídeo).
func _skin_posed(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var matrices: Array[Transform3D] = []
	for bind: int in skin.get_bind_count():
		var bone: int = skeleton.find_bone(skin.get_bind_name(bind))
		matrices.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var positions := PackedVector3Array()
	var posed_normals := PackedVector3Array()
	positions.resize(vertices.size())
	posed_normals.resize(vertices.size())
	for vertex: int in vertices.size():
		var point := Vector3.ZERO
		var normal := Vector3.ZERO
		for i: int in influences:
			var weight: float = weights[vertex * influences + i]
			if weight <= 0.0:
				continue
			var matrix: Transform3D = matrices[bones[vertex * influences + i]]
			point += (matrix * vertices[vertex]) * weight
			normal += (matrix.basis * normals[vertex]) * weight
		positions[vertex] = point
		posed_normals[vertex] = normal.normalized()
	return [positions, posed_normals]


# ---------------------------------------------------------------- corpo

# Leva os vértices (e normais e tangentes) para a pose de descanso do esqueleto da roupa.
func _to_outfit_space(arrays: Array, skin: Skin, outfit_skeleton: Skeleton3D) -> Array:
	var to_outfit: Array[Transform3D] = []
	for bind: int in skin.get_bind_count():
		var bone: int = outfit_skeleton.find_bone(skin.get_bind_name(bind))
		to_outfit.append(outfit_skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(bind))
	var result: Array = arrays.duplicate()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null \
			else PackedFloat32Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var new_vertices := PackedVector3Array()
	var new_normals := PackedVector3Array()
	var new_tangents := PackedFloat32Array()
	new_vertices.resize(vertices.size())
	new_normals.resize(vertices.size())
	new_tangents.resize(tangents.size())
	for vertex: int in vertices.size():
		var point := Vector3.ZERO
		var normal := Vector3.ZERO
		var tangent := Vector3.ZERO
		var original_tangent := Vector3.ZERO
		if not tangents.is_empty():
			original_tangent = Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
		for i: int in influences:
			var weight: float = weights[vertex * influences + i]
			if weight <= 0.0:
				continue
			var xform: Transform3D = to_outfit[bones[vertex * influences + i]]
			point += (xform * vertices[vertex]) * weight
			normal += (xform.basis * normals[vertex]) * weight
			tangent += (xform.basis * original_tangent) * weight
		new_vertices[vertex] = point
		new_normals[vertex] = normal.normalized()
		if not tangents.is_empty():
			tangent = tangent.normalized()
			new_tangents[vertex * 4] = tangent.x
			new_tangents[vertex * 4 + 1] = tangent.y
			new_tangents[vertex * 4 + 2] = tangent.z
			new_tangents[vertex * 4 + 3] = tangents[vertex * 4 + 3]
	result[Mesh.ARRAY_VERTEX] = new_vertices
	result[Mesh.ARRAY_NORMAL] = new_normals
	if not tangents.is_empty():
		result[Mesh.ARRAY_TANGENT] = new_tangents
	return result


# Peso de cada vértice nos ossos de um grupo (pelo começo do nome, ou nome exato).
func _weight_on(arrays: Array, skin: Skin, vertex: int, names: Array[String], prefix: bool) -> float:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var total: float = 0.0
	for i: int in influences:
		var bone_name: String = skin.get_bind_name(bones[vertex * influences + i])
		var matches: bool = names.any(func(n: String) -> bool: return bone_name.begins_with(n)) if prefix \
				else bone_name in names
		if matches:
			total += weights[vertex * influences + i]
	return total


# Quanto cada vértice está "dentro" do que fica (> 0 fica, < 0 sai). A cabeça sempre; fora dela,
# a coluna do pescoço (valor contínuo: 1 no eixo, 0 na borda da elipse — é por ele que a malha é
# cortada, com a borda lisa) e a pele do decote que não tem tecido na frente. A pele que fura a
# roupa sai. `under` recebe 1 para a pele que fica debaixo do tecido (vai dobrar com a roupa).
func _choose(posed: Array, skin: Skin, world: World3D, under: PackedByteArray) -> PackedFloat32Array:
	var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = posed[Mesh.ARRAY_NORMAL]
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var inside := PackedFloat32Array()
	inside.resize(vertices.size())
	under.resize(vertices.size())
	for vertex: int in vertices.size():
		var point: Vector3 = vertices[vertex]
		var normal: Vector3 = normals[vertex]
		inside[vertex] = -1.0
		if _weight_on(posed, skin, vertex, ["Head"], false) >= HEAD_WEIGHT:
			inside[vertex] = 1.0
			continue
		if point.y < NECKLINE_BOTTOM or _weight_on(posed, skin, vertex, ARM_BONES, true) >= 0.5:
			continue
		var column: float = 1.0 - ((Vector2(point.x, point.z) - NECK_CENTER) / NECK_RADII).length()
		if column < 0.0:
			var front: bool = point.z > NECK_CENTER.y and absf(point.x) <= NECKLINE_HALF_WIDTH
			var covered: bool = point.y < CHEST_TOP and _hits(space, point, normal * COVERED_REACH)
			if front and not covered:
				column = 0.2
		if column < 0.0:
			inside[vertex] = column
			continue
		under[vertex] = 1 if _hits(space, point, normal * REACH_OUT) else 0
		inside[vertex] = -1.0 if _hits(space, point, -normal * REACH_IN) else column
	return inside


func _hits(space: PhysicsDirectSpaceState3D, from: Vector3, along: Vector3) -> bool:
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + along)).is_empty()


# A pele que fica passa a dobrar como a roupa em volta dela. Debaixo do tecido: 100% com a roupa
# (inclusive a base do pescoço dentro da gola; se ela seguisse o pescoço, subia por cima do tecido
# quando a cabeça inclina). À mostra: o peso na cabeça e no pescoço é o original e o resto vem da
# roupa. Os pesos da roupa são os do ponto dela mais perto (mesmos ossos, pelo nome).
func _transfer_weights(posed: Array, keep: PackedByteArray, under: PackedByteArray, skin: Skin,
		cloth: Dictionary) -> void:
	var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = posed[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = posed[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var bind_of: Dictionary[String, int] = {}
	for bind: int in skin.get_bind_count():
		bind_of[skin.get_bind_name(bind)] = bind
	var cloth_points: PackedVector3Array = cloth["points"]
	var cloth_weights: Array[Dictionary] = cloth["weights"]
	for vertex: int in vertices.size():
		if not keep[vertex]:
			continue
		var named: Dictionary[String, float] = {}
		var head: float = 0.0
		if not under[vertex]:
			for i: int in influences:
				var weight: float = weights[vertex * influences + i]
				var bone_name: String = skin.get_bind_name(bones[vertex * influences + i])
				if weight > 0.0 and bone_name in HEAD_BONES:
					named[bone_name] = named.get(bone_name, 0.0) + weight
					head += weight
			if head >= 0.999:
				continue
		var nearest: int = _nearest(cloth_points, vertices[vertex])
		var borrowed: Dictionary = cloth_weights[nearest]
		for bone_name: String in borrowed:
			named[bone_name] = named.get(bone_name, 0.0) + borrowed[bone_name] * (1.0 - head)
		# Os MAX_INFLUENCES maiores, somando 1.
		var names: Array = named.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return named[a] > named[b])
		names = names.slice(0, influences)
		var total: float = 0.0
		for bone_name: String in names:
			total += named[bone_name]
		for i: int in influences:
			if i < names.size():
				bones[vertex * influences + i] = bind_of[names[i]]
				weights[vertex * influences + i] = named[names[i]] / total
			else:
				bones[vertex * influences + i] = 0
				weights[vertex * influences + i] = 0.0
	posed[Mesh.ARRAY_BONES] = bones
	posed[Mesh.ARRAY_WEIGHTS] = weights


func _nearest(points: PackedVector3Array, target: Vector3) -> int:
	var best: int = 0
	var best_distance: float = INF
	for index: int in points.size():
		var distance: float = points[index].distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


# Renumera os ossos de uma malha (olhos, sobrancelhas) para a numeração do Skin do corpo.
func _rebind(arrays: Array, from_skin: Skin, to_skin: Skin) -> void:
	var bind_of: Dictionary[String, int] = {}
	for bind: int in to_skin.get_bind_count():
		bind_of[to_skin.get_bind_name(bind)] = bind
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	for i: int in bones.size():
		bones[i] = bind_of[from_skin.get_bind_name(bones[i])]
	arrays[Mesh.ARRAY_BONES] = bones


# 1 = vértice dentro, ou vértice de fora num triângulo que tem algum vértice dentro.
func _near_inside(arrays: Array, inside: PackedFloat32Array) -> PackedByteArray:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var keep := PackedByteArray()
	keep.resize(inside.size())
	for corner: int in range(0, indices.size(), 3):
		var tri: Array[int] = [indices[corner], indices[corner + 1], indices[corner + 2]]
		if inside[tri[0]] >= 0.0 or inside[tri[1]] >= 0.0 or inside[tri[2]] >= 0.0:
			for vertex: int in tri:
				keep[vertex] = 1
	return keep


# Corta a malha onde `inside` passa por zero: triângulo todo dentro fica, todo fora sai, e o que
# cruza a borda é recortado com vértices novos no meio das arestas (posição, normal, textura e
# pesos interpolados). A borda fica lisa em vez de seguir os triângulos em dentes.
func _clip(arrays: Array, inside: PackedFloat32Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count: int = vertices.size()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / count
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	var out_uvs := PackedVector2Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var out_indices := PackedInt32Array()
	var reuse: Dictionary = {}

	# Acrescenta o ponto entre os vértices a e b, a `t` de a (t = 0 é o próprio a).
	var emit := func(a: int, b: int, t: float) -> int:
		var key: Variant = a if t <= 0.0 else Vector3i(mini(a, b), maxi(a, b), 0)
		if reuse.has(key):
			return reuse[key]
		var index: int = out_vertices.size()
		out_vertices.append(vertices[a].lerp(vertices[b], t))
		out_normals.append(normals[a].lerp(normals[b], t).normalized())
		if not uvs.is_empty():
			out_uvs.append(uvs[a].lerp(uvs[b], t))
		if not tangents.is_empty():
			for i: int in 4:
				out_tangents.append(lerpf(tangents[a * 4 + i], tangents[b * 4 + i], t) if i < 3 else tangents[a * 4 + 3])
		var mix: Dictionary[int, float] = {}
		for i: int in influences:
			mix[bones[a * influences + i]] = mix.get(bones[a * influences + i], 0.0) + weights[a * influences + i] * (1.0 - t)
			mix[bones[b * influences + i]] = mix.get(bones[b * influences + i], 0.0) + weights[b * influences + i] * t
		var order: Array = mix.keys()
		order.sort_custom(func(x: int, y: int) -> bool: return mix[x] > mix[y])
		var total: float = 0.0
		for i: int in mini(influences, order.size()):
			total += mix[order[i]]
		for i: int in influences:
			var has: bool = i < order.size() and total > 0.0
			out_bones.append(order[i] if has else 0)
			out_weights.append(mix[order[i]] / total if has else 0.0)
		reuse[key] = index
		return index

	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for corner: int in range(0, indices.size(), 3):
		var tri: Array[int] = [indices[corner], indices[corner + 1], indices[corner + 2]]
		var polygon: Array[int] = []
		for k: int in 3:
			var a: int = tri[k]
			var b: int = tri[(k + 1) % 3]
			if inside[a] >= 0.0:
				polygon.append(emit.call(a, a, 0.0))
			if (inside[a] >= 0.0) != (inside[b] >= 0.0):
				var t: float = inside[a] / (inside[a] - inside[b])
				# Mesma aresta vista pelo outro triângulo: mesmo vértice novo (a chave ignora a ordem).
				if a > b:
					polygon.append(emit.call(b, a, 1.0 - t))
				else:
					polygon.append(emit.call(a, b, t))
		for k: int in range(1, polygon.size() - 1):
			out_indices.append_array([polygon[0], polygon[k], polygon[k + 1]])

	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = out_vertices
	result[Mesh.ARRAY_NORMAL] = out_normals
	if not tangents.is_empty():
		result[Mesh.ARRAY_TANGENT] = out_tangents
	if not uvs.is_empty():
		result[Mesh.ARRAY_TEX_UV] = out_uvs
	result[Mesh.ARRAY_BONES] = out_bones
	result[Mesh.ARRAY_WEIGHTS] = out_weights
	result[Mesh.ARRAY_INDEX] = out_indices
	return result


# Caixa dos vértices presos à cabeça (o chapéu se assenta por ela).
func _head_box(posed: Array, skin: Skin) -> AABB:
	var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
	var box := AABB()
	var first: bool = true
	for vertex: int in vertices.size():
		if _weight_on(posed, skin, vertex, ["Head"], false) < HEAD_WEIGHT:
			continue
		if first:
			box = AABB(vertices[vertex], Vector3.ZERO)
			first = false
		else:
			box = box.expand(vertices[vertex])
	return box


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
		var surface_arrays: Array = mesh.surface_get_arrays(surface)
		var indices: Variant = surface_arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() if indices != null else (surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total
