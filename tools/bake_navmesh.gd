extends SceneTree
## Ferramenta: calcula a navmesh de uma fase e salva em arquivo (o jogo não precisa calcular
## ao abrir, o que pesaria no celular). Rodar de novo sempre que mudar o cenário:
##   Godot --headless --path . -s res://tools/bake_navmesh.gd                      (fase de teste)
##   Godot --headless --path . -s res://tools/bake_navmesh.gd -- <fase.tscn> <navmesh.tres>

const DEFAULT_LEVEL := "res://levels/test_level.tscn"
const DEFAULT_TARGET := "res://levels/test_level_navmesh.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level_path: String = args[0] if args.size() >= 2 else DEFAULT_LEVEL
	var target_path: String = args[1] if args.size() >= 2 else DEFAULT_TARGET
	var level: Node = (load(level_path) as PackedScene).instantiate()
	root.add_child(level)
	# As formas CSG só geram a malha depois do primeiro quadro.
	for i in 3:
		await process_frame
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	region.bake_navigation_mesh(false)
	var mesh: NavigationMesh = region.navigation_mesh
	print("polygons: ", mesh.get_polygon_count(), "  vertices: ", mesh.get_vertices().size())
	var err: Error = ResourceSaver.save(mesh, target_path)
	print("saved -> ", target_path, " (", error_string(err), ")")
	quit(0 if err == OK and mesh.get_polygon_count() > 0 else 1)
