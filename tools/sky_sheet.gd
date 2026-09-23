extends SceneTree
## Ferramenta de conferência do SkyCycle: fotografa a arena em vários momentos da partida (tarde,
## pôr do sol, crepúsculo, noite) de três pontos: a praça olhando o poente, olhando o nascer da
## lua e uma rua com os postes.
##   Godot --path . -s res://tools/sky_sheet.gd --resolution 1280x720 --always-on-top -- <pasta absoluta>
## Salva <pasta>/<vista>_<momento>.png.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const MOMENTS: Array[float] = [0.0, 0.3, 0.44, 0.6, 0.85]
## [posição da câmera, ponto para onde olha]
const VIEWS: Dictionary[String, Array] = {
	"poente": [Vector3(14.0, 3.2, 4.0), Vector3(-30.0, 6.0, 12.0)],
	"lua": [Vector3(-12.0, 2.5, 6.0), Vector3(30.0, 18.0, -22.0)],
	"rua": [Vector3(-42.0, 2.6, -17.0), Vector3(-46.5, 1.0, 2.0)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	(level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	for layer: Node in level.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for node: Node in get_nodes_in_group(&"bots"):
		((node as Character).controller as BotController).passive = true
	await _frames(20)
	var cycle := level.find_child("SkyCycle", true, false) as SkyCycle
	var camera := Camera3D.new()
	camera.fov = 70.0
	level.add_child(camera)
	camera.current = true
	for moment: float in MOMENTS:
		cycle.forced_progress = moment
		for view_name: String in VIEWS:
			var spec: Array = VIEWS[view_name]
			camera.global_position = spec[0]
			camera.look_at(spec[1])
			# O reflexo do céu se atualiza aos poucos: espera alguns quadros.
			await _frames(14)
			_shot("%s_%02d" % [view_name, roundi(moment * 100.0)])
	quit()


func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


func _shot(shot_name: String) -> void:
	var path: String = OS.get_cmdline_user_args()[0].path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)
