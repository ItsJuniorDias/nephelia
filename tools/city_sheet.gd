extends SceneTree
## Ferramenta de conferência: fotos da cidade de pontos fixos, à tarde e à noite, sem HUD e sem
## personagens (para comparar o antes e depois das mudanças no cenário).
##   Godot --path . -s res://tools/city_sheet.gd --resolution 640x360 --always-on-top -- <pasta absoluta> [prefixo] [ponto]
## Salva <pasta>/<prefixo>_<ponto>_<tarde|noite>.png (1280 x 720).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
## [nome, posição da câmera, para onde olha]. Norte = -Z, leste = +X.
const VIEWS: Array = [
	["praca", Vector3(-9.0, 1.7, 18.0), Vector3(6.0, 4.0, -10.0)],
	["praca_alto", Vector3(16.0, 12.0, 26.0), Vector3(-2.0, 2.0, -4.0)],
	["oeste_rua", Vector3(-38.0, 2.7, -14.0), Vector3(-48.0, 4.0, 8.0)],
	["leste_lojas", Vector3(36.0, 0.7, 10.0), Vector3(50.0, 3.0, -6.0)],
	["janelas_perto", Vector3(6.0, 2.0, 14.0), Vector3(15.0, 5.0, 12.0)],
	["do_trilho", Vector3(8.0, 8.0, 26.0), Vector3(-8.0, 2.0, 0.0)],
	["banco", Vector3(13.0, 1.7, 3.0), Vector3(17.0, 7.0, -10.0)],
	["cortico", Vector3(-13.0, 1.7, 3.0), Vector3(-17.0, 7.0, -10.0)],
	["hotel", Vector3(3.0, 1.7, 13.0), Vector3(10.0, 7.0, 17.0)],
	["ponte", Vector3(-12.0, 1.7, 1.5), Vector3(-30.0, 3.0, 0.0)],
	["aerea", Vector3(10.0, 55.0, 78.0), Vector3(0.0, -2.0, 0.0)],
	["aerea_oeste", Vector3(-20.0, 26.0, 30.0), Vector3(-46.0, 0.0, -2.0)],
	["aerea_leste", Vector3(20.0, 24.0, -30.0), Vector3(46.0, 0.0, 2.0)],
]
const MOMENTS: Array = [["tarde", 0.15], ["noite", 0.85]]
## Terceiro argumento opcional: só os pontos cujo nome começa com ele (ex.: "aerea").

var _view: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	var prefix: String = args[1] if args.size() > 1 else "cidade"
	DirAccess.make_dir_recursive_absolute(out)
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var level: Node3D = (load(ARENA) as PackedScene).instantiate()
	_view.add_child(level)
	(level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	for node: Node in get_nodes_in_group(&"characters"):
		var character := node as Character
		character.visible = false
		character.process_mode = Node.PROCESS_MODE_DISABLED
		for layer: Node in character.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	level.add_child(camera)
	camera.current = true
	await _frames(10)
	var sky := level.find_child("SkyCycle", true, false) as SkyCycle
	for moment: Array in MOMENTS:
		sky.forced_progress = moment[1]
		await _frames(40)
		for view: Array in VIEWS:
			if args.size() > 2 and not String(view[0]).begins_with(args[2]):
				continue
			camera.global_position = view[1]
			camera.look_at(view[2], Vector3.UP)
			await _frames(8)
			var path: String = out.path_join("%s_%s_%s.png" % [prefix, view[0], moment[0]])
			_view.get_texture().get_image().save_png(path)
			print("SHOT ", path)
	quit()


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1
