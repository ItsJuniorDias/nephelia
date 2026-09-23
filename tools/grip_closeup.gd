extends SceneTree
## Ferramenta de conferência: close-up da mão direita segurando o revólver (de lado, por cima, por
## baixo e de frente) e a 1ª pessoa. Para acertar a pegada: cabo dentro do punho, indicador no gatilho.
##   Godot --path . -s res://tools/grip_closeup.gd --resolution 900x700 --always-on-top -- <pasta absoluta>

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
## Face do gatilho no espaço do revólver (onde a ponta do indicador tem que ficar).
const TRIGGER := Vector3(0.0, 0.075, 0.033)
const SPOT := Vector3(16.0, 0.05, -2.0)
## Câmeras em volta da mão (espaço do mundo, o bot olha para +Z): [deslocamento, campo de visão]
const VIEWS: Dictionary[String, Array] = {
	"mao_lado_direito": [Vector3(-0.45, 0.05, 0.05), 30.0],
	"mao_lado_esquerdo": [Vector3(0.45, 0.08, 0.1), 30.0],
	"mao_cima": [Vector3(-0.05, 0.45, 0.02), 30.0],
	"mao_baixo": [Vector3(-0.1, -0.4, 0.05), 30.0],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	(level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	var player: Character = level.get_node("Player")
	for layer: Node in player.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var bot: Character = null
	for node: Node in get_nodes_in_group(&"bots"):
		var other := node as Character
		other.set_physics_process(false)
		if bot == null:
			bot = other
		else:
			other.teleport(Transform3D(Basis.IDENTITY, Vector3(-44.0, 1.05, 12.0)))
	bot.teleport(Transform3D(Basis(Vector3.UP, PI), SPOT))
	player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(20.0, 0.05, -4.0)))
	player.set_physics_process(false)
	await _frames(20)
	var camera := Camera3D.new()
	camera.near = 0.01
	level.add_child(camera)
	camera.current = true
	var hand_bone: int = bot.model.skeleton.find_bone(&"hand_r")
	for view_name: String in VIEWS:
		bot.model.update_motion(0.0, 0.0)
		var hand: Vector3 = bot.model.skeleton.global_transform * bot.model.skeleton.get_bone_global_pose(hand_bone).origin
		var spec: Array = VIEWS[view_name]
		camera.fov = spec[1]
		camera.global_position = hand + (spec[0] as Vector3)
		camera.look_at(hand + Vector3(0.0, 0.03, 0.08), Vector3.UP if absf((spec[0] as Vector3).y) < 0.3 else Vector3.FORWARD)
		await _frames(6)
		_shot(view_name)
	# Bem perto do gatilho, dos dois lados da arma.
	for side: float in [-1.0, 1.0]:
		var gun: Transform3D = bot.model.gun.global_transform
		var trigger: Vector3 = gun * TRIGGER
		camera.fov = 22.0
		camera.global_position = trigger + gun.basis.x.normalized() * 0.22 * side + gun.basis.y.normalized() * 0.04
		camera.look_at(trigger, gun.basis.y.normalized())
		await _frames(6)
		_shot("gatilho_%s" % ("esquerda" if side < 0.0 else "direita"))
	player.camera.current = true
	await _frames(10)
	_shot("1a_pessoa")
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
