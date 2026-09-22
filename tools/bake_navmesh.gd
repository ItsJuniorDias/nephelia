extends SceneTree
## Ferramenta: calcula a navmesh da fase de teste e salva em arquivo (o jogo não precisa
## calcular ao abrir, o que pesaria no celular). Rodar de novo sempre que mudar o cenário:
##   Godot --headless --path . -s res://tools/bake_navmesh.gd

const LEVEL := "res://levels/test_level.tscn"
const TARGET := "res://levels/test_level_navmesh.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(level)
	# As formas CSG só geram a malha depois do primeiro quadro.
	for i in 3:
		await process_frame
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	region.bake_navigation_mesh(false)
	var mesh: NavigationMesh = region.navigation_mesh
	print("polygons: ", mesh.get_polygon_count(), "  vertices: ", mesh.get_vertices().size())
	var err: Error = ResourceSaver.save(mesh, TARGET)
	print("saved -> ", TARGET, " (", error_string(err), ")")
	quit(0 if err == OK and mesh.get_polygon_count() > 0 else 1)
