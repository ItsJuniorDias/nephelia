extends SceneTree
## Ferramenta: transforma o revólver do FBX numa malha própria do projeto.
##   Godot --headless --path . -s res://tools/bake_revolver.gd
##
## O FBX vem com a malha 100 vezes menor e o tamanho real numa escala no nó (3 mm de malha com
## escala 100). Isso confunde o nível de detalhe automático e a arma some no celular. Aqui a
## escala entra nos vértices, os materiais viram materiais simples do projeto (sem cor de
## vértice, que deixava o revólver azulado) e o resultado é salvo em `assets/models/weapons/`.

const SOURCE := "res://assets/models/weapons/lowpoly_wild_west/colt_revolver.fbx"
const TARGET := "res://assets/models/weapons/colt_revolver.res"
## Cores do modelo original (aço e cabo de madeira).
const STEEL := Color(0.31, 0.31, 0.31)
const WOOD := Color(0.35, 0.24, 0.17)


func _initialize() -> void:
	var scene: Node3D = (load(SOURCE) as PackedScene).instantiate()
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
	var err: Error = ResourceSaver.save(mesh, TARGET)
	print("saved %s (%s): surfaces=%d size=%s" % [TARGET, error_string(err), mesh.get_surface_count(),
			mesh.get_aabb().size.snappedf(0.001)])
	scene.free()
	quit(0 if err == OK else 1)


func _material(surface_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = surface_name
	material.albedo_color = WOOD if surface_name.begins_with("Brown") else STEEL
	material.metallic = 0.0 if surface_name.begins_with("Brown") else 0.4
	material.roughness = 0.75 if surface_name.begins_with("Brown") else 0.45
	return material


func _transform_to(node: Node3D, scene_root: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != scene_root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
