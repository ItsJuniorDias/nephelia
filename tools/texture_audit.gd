extends SceneTree
## Ferramenta: lista tudo na arena que está SEM TEXTURA (material só com cor lisa), agrupado por
## material, com quantas peças usam, a área aproximada que ocupa e onde fica.
##   Godot --headless --path . -s res://tools/texture_audit.gd [-- <cena>]

const DEFAULT_SCENE := "res://levels/skyplaza/skyplaza.tscn"

## material -> {"label", "color", "count", "area", "where": {nó: true}, "example": Vector3}
var _groups: Dictionary = {}
var _textured: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else DEFAULT_SCENE
	var level: Node = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 5:
		await process_frame
	for node: Node in level.find_children("*", "GeometryInstance3D", true, false):
		_inspect(node as GeometryInstance3D, level)
	var keys: Array = _groups.keys()
	keys.sort_custom(func(a, b) -> bool: return _groups[a]["area"] > _groups[b]["area"])
	print("=== SEM TEXTURA (%d materiais) ===" % keys.size())
	for key in keys:
		var g: Dictionary = _groups[key]
		var where: Array = g["where"].keys()
		where.sort()
		print("AREA %7.1f m²  x%-4d %-34s cor=%s  exemplo=%s  em: %s" % [g["area"], g["count"], g["label"],
				g["color"], g["example"], ", ".join(where.slice(0, 6))])
	print("=== COM TEXTURA: %d materiais ===" % _textured.size())
	quit()


func _inspect(geometry: GeometryInstance3D, level: Node) -> void:
	if not geometry.is_visible_in_tree():
		return
	var mesh: Mesh = null
	if geometry is MeshInstance3D:
		mesh = (geometry as MeshInstance3D).mesh
	elif geometry is CSGShape3D:
		var csg := geometry as CSGShape3D
		if not csg.is_root_shape():
			return
		var baked: Array = csg.get_meshes()
		if baked.size() >= 2:
			mesh = baked[1]
	elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
		mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
	elif geometry is CPUParticles3D or geometry is GPUParticles3D:
		return
	if mesh == null:
		return
	var where: String = _area_name(geometry, level)
	for surface: int in mesh.get_surface_count():
		var material: Material = geometry.material_override
		if material == null and geometry is MeshInstance3D:
			material = (geometry as MeshInstance3D).get_active_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		var area: float = _surface_area(mesh, surface, geometry.global_transform.basis)
		if material is BaseMaterial3D:
			var base := material as BaseMaterial3D
			if base.albedo_texture != null:
				_textured[base] = true
				continue
			# Transparente e sem sombra (clarões, marcas, nuvens de efeito) não conta.
			if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			_add(base, _label(base, geometry), base.albedo_color, area, where, geometry.global_position)
		elif material == null:
			_add(mesh, "(sem material) " + geometry.name, Color.WHITE, area, where, geometry.global_position)
		# ShaderMaterial: fica de fora (feito à mão, com cor calculada no shader).


func _add(key: Variant, label: String, color: Color, area: float, where: String, at: Vector3) -> void:
	if not _groups.has(key):
		_groups[key] = {"label": label, "color": "#" + color.to_html(false), "count": 0, "area": 0.0,
				"where": {}, "example": at.snappedf(0.1)}
	_groups[key]["count"] += 1
	_groups[key]["area"] += area
	_groups[key]["where"][where] = true


func _label(material: BaseMaterial3D, geometry: GeometryInstance3D) -> String:
	if not material.resource_path.is_empty() and not material.resource_path.contains("::"):
		return material.resource_path.get_file()
	if not material.resource_name.is_empty():
		return material.resource_name
	return "(%s)" % geometry.name


# De onde é a peça: o primeiro nível dentro da cena e o nome do nó (ex.: "Geometry/WestPark").
func _area_name(node: Node, level: Node) -> String:
	var path: String = String(level.get_path_to(node))
	var parts: PackedStringArray = path.split("/")
	if parts.size() <= 2:
		return path
	return "%s/%s" % [parts[0], parts[1].rstrip("0123456789").trim_prefix("@").rstrip("@")]


# Área da superfície (m²) já na escala do nó.
func _surface_area(mesh: Mesh, surface: int, basis: Basis) -> float:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Malha sem lista de índices: cada três vértices seguidos são um triângulo.
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	var total: float = 0.0
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	for i in range(0, count - 2, 3):
		var a: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
		var b: Vector3 = vertices[indices[i + 1] if not indices.is_empty() else i + 1]
		var c: Vector3 = vertices[indices[i + 2] if not indices.is_empty() else i + 2]
		total += (basis * (b - a)).cross(basis * (c - a)).length() * 0.5
	return total
