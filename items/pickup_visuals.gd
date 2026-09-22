class_name PickupVisuals
extends RefCounted
## Monta a aparência dos itens em código: frascos de tônico (vida vermelha, energia azul) e o
## brilho redondo no chão, que ajuda a achar o item de longe. Materiais compartilhados entre
## todos os itens (menos trocas de material no celular).

const HEALTH_COLOR := Color(0.95, 0.18, 0.2)
const ENERGY_COLOR := Color(0.3, 0.7, 1.0)
const WEAPON_COLOR := Color(1.0, 0.8, 0.4)

static var _materials: Dictionary[String, Material] = {}


## Parte que flutua e gira (o frasco ou a arma).
static func build(kind: Pickup.Kind) -> Node3D:
	match kind:
		Pickup.Kind.ENERGY:
			return _bottle("energy", ENERGY_COLOR)
		_:
			return _bottle("health", HEALTH_COLOR)


## Brilho no chão, da cor do item.
static func build_glow(kind: Pickup.Kind) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	quad.orientation = PlaneMesh.FACE_Y
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = quad
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = 0.03
	glow.material_override = _glow_material(color_of(kind))
	return glow


static func color_of(kind: Pickup.Kind) -> Color:
	match kind:
		Pickup.Kind.HEALTH:
			return HEALTH_COLOR
		Pickup.Kind.ENERGY:
			return ENERGY_COLOR
	return WEAPON_COLOR


# Frasco de tônico: corpo de vidro colorido que brilha, rótulo creme, gargalo e tampa de latão.
static func _bottle(key: String, color: Color) -> Node3D:
	var bottle := Node3D.new()
	bottle.name = "Bottle"
	var liquid: Material = _liquid_material(key, color)
	_part(bottle, _cylinder(0.14, 0.15, 0.3), liquid, -0.1)
	_part(bottle, _sphere(0.145, 0.16), liquid, 0.05)
	_part(bottle, _cylinder(0.152, 0.152, 0.1), _solid_material("label", Color(0.93, 0.88, 0.75), 0.0, 0.8), -0.11)
	_part(bottle, _cylinder(0.045, 0.06, 0.12), liquid, 0.17)
	_part(bottle, _cylinder(0.055, 0.055, 0.05), _solid_material("brass", Color(0.78, 0.6, 0.25), 0.8, 0.35), 0.25)
	return bottle


static func _part(parent: Node3D, mesh: Mesh, material: Material, height: float) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position.y = height
	# Sem sombra: a sombra do frasco mancharia o brilho no chão (que é aditivo).
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


static func _liquid_material(key: String, color: Color) -> Material:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.3)
		material.roughness = 0.15
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
		_materials[key] = material
	return _materials[key]


static func _solid_material(key: String, color: Color, metallic: float, roughness: float) -> Material:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]


static func _glow_material(color: Color) -> Material:
	var key: String = "glow_%s" % color.to_html()
	if not _materials.has(key):
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.8))
		gradient.set_color(1, Color(1, 1, 1, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = texture
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]
