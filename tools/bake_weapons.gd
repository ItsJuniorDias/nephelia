extends SceneTree
## Ferramenta: transforma as armas do FBX em malhas próprias do projeto.
##   Godot --headless --path . -s res://tools/bake_weapons.gd
##
## Os FBX do pacote vêm com a malha 100 vezes menor e o tamanho real numa escala no nó (o
## revólver tem 3 mm de malha com escala 100). Isso confunde o nível de detalhe automático e a
## arma some no celular. Aqui a escala entra nos vértices, os materiais viram materiais simples
## do projeto (sem cor de vértice, que deixava as armas azuladas) e o resultado é salvo em
## `assets/models/weapons/`. No fim imprime o tamanho e a ponta do cano de cada arma (o ponto
## de onde sai o rastro do tiro, usado em `weapons/weapon_catalog.gd`).

const SOURCE_DIR := "res://assets/models/weapons/lowpoly_wild_west/"
const TARGET_DIR := "res://assets/models/weapons/"
const WEAPONS: Array[String] = ["colt_revolver", "repeater", "double_barrel_shotgun"]
## Cores do modelo original (aço, aço escuro, ferro preto e cabo de madeira).
const STEEL := Color(0.31, 0.31, 0.31)
const DARK_STEEL := Color(0.19, 0.19, 0.2)
const BLACK_IRON := Color(0.09, 0.09, 0.1)
const WOOD := Color(0.35, 0.24, 0.17)


func _initialize() -> void:
	var failures: int = 0
	for weapon_name: String in WEAPONS:
		if not _bake(weapon_name):
			failures += 1
	quit(0 if failures == 0 else 1)


func _bake(weapon_name: String) -> bool:
	var scene: Node3D = (load(SOURCE_DIR + weapon_name + ".fbx") as PackedScene).instantiate()
	var tools: Dictionary[String, SurfaceTool] = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var to_root: Transform3D = _transform_to(instance, scene)
		for surface: int in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var key: String = source.resource_name if source != null else "Grey"
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = tool
			tools[key].append_from(instance.mesh, surface, to_root)

	var mesh := ArrayMesh.new()
	for key: String in tools:
		var tool: SurfaceTool = tools[key]
		tool.index()
		tool.generate_tangents()
		tool.set_material(_material(key))
		tool.commit(mesh)
	var target: String = TARGET_DIR + weapon_name + ".res"
	var err: Error = ResourceSaver.save(mesh, target)
	print("saved %s (%s): surfaces=%d aabb=%s size=%s muzzle=%s" % [target, error_string(err),
			mesh.get_surface_count(), mesh.get_aabb().position.snappedf(0.001),
			mesh.get_aabb().size.snappedf(0.001), _muzzle(mesh).snappedf(0.0001)])
	scene.free()
	return err == OK


# Ponta do cano: média dos vértices mais à frente (a arma aponta para -Z depois de assada).
func _muzzle(mesh: ArrayMesh) -> Vector3:
	var front: float = mesh.get_aabb().position.z
	var sum := Vector3.ZERO
	var count: int = 0
	for surface: int in mesh.get_surface_count():
		for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if vertex.z < front + 0.01:
				sum += vertex
				count += 1
	return sum / maxi(count, 1)


func _material(surface_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = surface_name
	var wood: bool = surface_name.begins_with("Brown")
	if wood:
		material.albedo_color = WOOD
	elif surface_name.begins_with("Black"):
		material.albedo_color = BLACK_IRON
	elif surface_name.begins_with("Dark"):
		material.albedo_color = DARK_STEEL
	else:
		material.albedo_color = STEEL
	# Aço fosco: brilhante demais, a arma vista de fora refletia o céu e parecia branca.
	material.metallic = 0.0 if wood else 0.2
	material.roughness = 0.75 if wood else 0.6
	return material


func _transform_to(node: Node3D, scene_root: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != scene_root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
