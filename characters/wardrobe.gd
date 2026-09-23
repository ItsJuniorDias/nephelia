class_name Wardrobe
extends RefCounted
## Monta o corpo de um personagem a partir da ficha dele (CharacterLook): a roupa, que já traz
## o esqueleto, os braços, as mãos e as pernas (Modular Character Outfits, roupa Peasant), o
## corpo original com a cabeça intacta (sem o que a roupa cobre), o cabelo, a barba e o chapéu.
## Sem roupa (`dressed` falso, os bots) é o corpo original inteiro do Universal Base Characters.
##
## Tudo em código, e não guardado na cena: nó guardado dentro de cena importada some no build
## do iPhone (ver CLAUDE.md). As peças vestidas são malhas presas ao mesmo esqueleto (pelos
## nomes dos ossos), então animam junto com a roupa.

const OUTFITS: Dictionary[CharacterLook.Body, PackedScene] = {
	CharacterLook.Body.MALE: preload("res://assets/models/characters/quaternius_outfits/Male_Peasant.gltf"),
	CharacterLook.Body.FEMALE: preload("res://assets/models/characters/quaternius_outfits/Female_Peasant.gltf"),
}
## As duas estampas da roupa Peasant (a segunda troca as cores do tecido).
const OUTFIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/models/characters/quaternius_outfits/T_Peasant_BaseColor.png"),
	preload("res://assets/models/characters/quaternius_outfits/T_Peasant_2_BaseColor.png"),
]
## O corpo original (cabeça, rosto e pescoço intactos), sem o que a roupa cobre.
const BODIES: Dictionary[CharacterLook.Body, String] = {
	CharacterLook.Body.MALE: "res://assets/models/characters/parts/body_male.res",
	CharacterLook.Body.FEMALE: "res://assets/models/characters/parts/body_female.res",
}
## O corpo inteiro, sem roupa (é o glTF original, com o esqueleto dentro).
const PLAIN_BODIES: Dictionary[CharacterLook.Body, String] = {
	CharacterLook.Body.MALE: "res://assets/models/characters/quaternius_ubc/Superhero_Male_FullBody.gltf",
	CharacterLook.Body.FEMALE: "res://assets/models/characters/quaternius_ubc/Superhero_Female_FullBody.gltf",
}
const PARTS_DIR := "res://assets/models/characters/parts/"
## Material do tecido da roupa (o resto é pele): é nele que entra a cor do personagem.
const CLOTH_MATERIAL_PREFIX := "MI_Peasant"
const HAT_MATERIAL_NAME := "Hat"


## Corpo pronto para pôr no modelo (nó raiz com Armature/Skeleton3D dentro, como o glTF).
static func build(look: CharacterLook) -> Node3D:
	var body_part: CharacterPart = load(BODIES[look.body])
	if not look.dressed:
		var plain: Node3D = (load(PLAIN_BODIES[look.body]) as PackedScene).instantiate()
		plain.name = "Model"
		_add_extras(plain.get_node("Armature/Skeleton3D") as Skeleton3D, look, body_part)
		return plain
	var body: Node3D = OUTFITS[look.body].instantiate()
	body.name = "Model"
	var skeleton := body.get_node("Armature/Skeleton3D") as Skeleton3D
	_apply_outfit_variant(skeleton, look.outfit_variant)
	_dye(_wear(skeleton, "Body", body_part), look.hair_color, "Eyebrows")
	_add_extras(skeleton, look, body_part)
	return body


# Cabelo, barba e chapéu (servem no corpo com e sem roupa: o esqueleto é o mesmo padrão).
static func _add_extras(skeleton: Skeleton3D, look: CharacterLook, body_part: CharacterPart) -> void:
	var hair: String = _hair_file(look)
	if not hair.is_empty():
		_dye(_wear(skeleton, "Hair", load(PARTS_DIR + hair) as CharacterPart), look.hair_color)
	if look.beard:
		_dye(_wear(skeleton, "Beard", load(PARTS_DIR + "beard.res") as CharacterPart), look.hair_color)
	if look.hat != CharacterLook.Hat.NONE:
		_wear_hat(skeleton, look, body_part.head_box)


## É o tecido da roupa (recebe a cor do personagem)?
static func is_cloth(material: Material) -> bool:
	return material != null and material.resource_name.begins_with(CLOTH_MATERIAL_PREFIX)


static func _wear(skeleton: Skeleton3D, part_name: String, part: CharacterPart) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = part.mesh
	instance.skin = part.skin
	# Filho do esqueleto, ligado a ele. O caminho PRECISA ser dado: numa malha criada em código
	# ele vem vazio (não ".."), e aí a malha fica parada na pose de descanso. A cabeça, o cabelo e
	# o chapéu ficaram assim um tempo: parado não aparecia, mas correndo o corpo balançava e a
	# cabeça ficava no ar (visto pelo usuário no vídeo do bot).
	instance.skeleton = NodePath("..")
	skeleton.add_child(instance)
	return instance


# Pinta os pelos (a textura do pacote é cinza). `only_surface` vazio = a malha toda.
static func _dye(instance: MeshInstance3D, color: Color, only_surface: String = "") -> void:
	for surface: int in instance.mesh.get_surface_count():
		if not only_surface.is_empty() and instance.mesh.surface_get_name(surface) != only_surface:
			continue
		var material := instance.get_active_material(surface).duplicate() as BaseMaterial3D
		material.albedo_color = color
		instance.set_surface_override_material(surface, material)


static func _hair_file(look: CharacterLook) -> String:
	match look.hair:
		CharacterLook.Hair.BUZZED:
			return "hair_buzzed_female.res" if look.body == CharacterLook.Body.FEMALE else "hair_buzzed.res"
		CharacterLook.Hair.PARTED:
			return "hair_parted.res"
		CharacterLook.Hair.LONG:
			return "hair_long.res"
		CharacterLook.Hair.BUNS:
			return "hair_buns.res"
	return ""


# Troca a estampa do tecido (material novo só deste personagem, o importado não muda).
static func _apply_outfit_variant(skeleton: Skeleton3D, variant: int) -> void:
	var texture: Texture2D = OUTFIT_TEXTURES[clampi(variant, 0, OUTFIT_TEXTURES.size() - 1)]
	for node: Node in skeleton.get_children():
		var instance := node as MeshInstance3D
		if instance == null:
			continue
		for surface: int in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as BaseMaterial3D
			if is_cloth(source):
				var material := source.duplicate() as BaseMaterial3D
				material.albedo_texture = texture
				instance.set_surface_override_material(surface, material)


# ---------------------------------------------------------------- chapéus

# Chapéu montado com formas simples (coco, cartola, boina), preso ao osso da cabeça. As medidas
# saem da cabeça (`head_box`, no espaço do esqueleto): serve nos dois corpos.
static func _wear_hat(skeleton: Skeleton3D, look: CharacterLook, head_box: AABB) -> void:
	var top: float = head_box.end.y
	var radius: float = head_box.size.x * 0.5 + 0.014
	var center := Vector3(0.0, top - 0.072, head_box.get_center().z - 0.012)
	var pieces: Array[Array] = []
	match look.hat:
		CharacterLook.Hat.BOWLER:
			# Aba curta e copa redonda.
			pieces.append([_cylinder(radius + 0.032, radius + 0.032, 0.012), Vector3(0.0, 0.0, 0.0)])
			pieces.append([_cylinder(radius, radius, 0.026), Vector3(0.0, 0.013, 0.0)])
			pieces.append([_dome(radius, 0.064), Vector3(0.0, 0.026, 0.0)])
		CharacterLook.Hat.TOP_HAT:
			# Aba e copa alta, um pouco mais larga em cima.
			pieces.append([_cylinder(radius + 0.042, radius + 0.042, 0.012), Vector3(0.0, 0.0, 0.0)])
			pieces.append([_cylinder(radius + 0.006, radius - 0.004, 0.17), Vector3(0.0, 0.085, 0.0)])
		CharacterLook.Hat.FLAT_CAP:
			# Boina de jornaleiro: copa larga e baixa, puxada para a frente, e pala curta.
			pieces.append([_dome(radius + 0.026, 0.044), Vector3(0.0, 0.006, 0.02)])
			pieces.append([_visor(radius), Vector3(0.0, 0.0, radius + 0.012)])
	var instance := MeshInstance3D.new()
	instance.name = "Hat"
	instance.mesh = _skinned_hat(pieces, center, look.hat_color)
	var skin := Skin.new()
	# Os vértices estão no espaço do esqueleto parado: a ligação desfaz a pose de descanso da cabeça.
	var head_bone: int = skeleton.find_bone("Head")
	skin.add_named_bind("Head", skeleton.get_bone_global_rest(head_bone).affine_inverse())
	instance.skin = skin
	instance.skeleton = NodePath("..")
	skeleton.add_child(instance)


static func _skinned_hat(pieces: Array[Array], center: Vector3, color: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece: Array in pieces:
		var shape: Mesh = piece[0]
		tool.append_from(shape, 0, Transform3D(Basis.IDENTITY, center + (piece[1] as Vector3)))
	var arrays: Array = tool.commit_to_arrays()
	# Todos os vértices 100% no osso da cabeça (o único ligado no Skin).
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(count * 4)
	weights.resize(count * 4)
	for vertex: int in count:
		weights[vertex * 4] = 1.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = HAT_MATERIAL_NAME
	material.albedo_color = color
	material.roughness = 0.85
	mesh.surface_set_material(0, material)
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return mesh


# Meia esfera de raio `radius` e altura `height` (achatada), com a base em y = 0.
static func _dome(radius: float, height: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 20
	sphere.rings = 6
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(1.0, height / radius, 1.0)), Vector3.ZERO))
	return tool.commit()


# Pala da boina: um disco fino e achatado, inclinado para baixo, saindo da frente da copa.
static func _visor(radius: float) -> ArrayMesh:
	var disc := _cylinder(radius * 0.8, radius * 0.8, 0.01)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(16.0)) * Basis.from_scale(Vector3(1.0, 1.0, 0.5))
	tool.append_from(disc, 0, Transform3D(tilt, Vector3.ZERO))
	return tool.commit()
