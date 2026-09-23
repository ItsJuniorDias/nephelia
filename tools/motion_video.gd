extends SceneTree
## Ferramenta de conferência: grava um bot andando em todas as direções (para frente, de lado, de
## costas e na diagonal) mirando na câmera, como um inimigo visto pelo jogador. Serve para ver as
## pernas (LegsYawModifier) e o corpo em movimento, quadro a quadro.
##   Godot --path . -s res://tools/motion_video.gd --resolution 640x480 --write-movie <pasta>/f.png --fixed-fps 30 [-- <arma>]
## <arma> (opcional): "repeater" ou "shotgun" para ver as armas longas (padrão: revólver).
## Os quadros saem em <pasta>/f00000000.png... Cada fase dura FASE segundos (ver PHASES).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const START := Vector3(16.0, 0.05, -4.0)
## Câmera: distância e altura em relação ao bot (ela acompanha o bot).
const CAMERA_OFFSET := Vector3(1.2, 1.5, 5.0)
## [nome, direção do comando (x = direita, y = trás), segundos]
const PHASES: Array = [
	["parado", Vector2.ZERO, 0.6],
	["frente", Vector2(0, -1), 1.2],
	["esquerda", Vector2(-1, 0), 1.5],
	["direita", Vector2(1, 0), 1.5],
	["costas", Vector2(0, 1), 1.5],
	["diagonal_tras", Vector2(-0.7, 0.7), 1.2],
	["diagonal_frente", Vector2(0.7, -0.7), 1.2],
	["parado_fim", Vector2.ZERO, 0.6],
]


## Controlador de roteiro: anda na direção pedida e continua virado para a câmera.
class ScriptedController extends CharacterController:
	var move: Vector2 = Vector2.ZERO
	var face_yaw: float = 0.0

	func get_command(_delta: float) -> CharacterCommand:
		command.reset()
		command.move = move
		command.yaw = face_yaw
		command.pitch = 0.0
		return command


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
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 30.0)))
	player.set_physics_process(false)
	var bots: Array[Node] = get_nodes_in_group(&"bots")
	for node: Node in bots:
		var other := node as Character
		other.set_physics_process(false)
		other.teleport(Transform3D(Basis.IDENTITY, Vector3(-44.0, 1.05, 12.0)))
	# O bot da gravação troca o cérebro pelo roteiro.
	var bot := bots[0] as Character
	var brain := ScriptedController.new()
	bot.controller.queue_free()
	bot.add_child(brain)
	bot.controller = brain
	brain.setup(bot)
	brain.face_yaw = PI
	bot.teleport(Transform3D(Basis(Vector3.UP, PI), START))
	bot.set_physics_process(true)
	if not OS.get_cmdline_user_args().is_empty():
		(level.get_node("MatchReferee") as MatchReferee).give_weapon(bot, StringName(OS.get_cmdline_user_args()[0]))

	var camera := Camera3D.new()
	camera.fov = 45.0
	level.add_child(camera)
	camera.current = true
	for phase: Array in PHASES:
		brain.move = phase[1]
		print("PHASE %s frame %d" % [phase[0], Engine.get_frames_drawn()])
		var frames: int = roundi(float(phase[2]) * 30.0)
		for i in frames:
			camera.global_position = bot.global_position + CAMERA_OFFSET
			camera.look_at(bot.global_position + Vector3(0.0, 1.0, 0.0))
			await process_frame
	quit()
