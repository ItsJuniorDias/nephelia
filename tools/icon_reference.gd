extends SceneTree
## Fotos do jogo que servem de REFERÊNCIA DE ESTILO para a IA desenhar o ícone
## (`tools/make_icon.py --ref`): a cidade flutuante com os trilhos e o jogador de boina com o revólver.
##   Godot --path . -s res://tools/icon_reference.gd --resolution 1024x1024 --always-on-top -- <pasta absoluta>
## Salva <pasta>/ref_cidade.png e <pasta>/ref_personagem.png. Rodar com janela (escondida, o macOS
## para de desenhar e as fotos saem repetidas).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
## Onde o jogador posa para a foto (braço leste da praça, céu atrás).
const POSE_AT := Vector3(14.0, 0.05, 0.0)
## [posição da câmera, ponto para onde olha, campo de visão]
const SHOTS: Dictionary[String, Array] = {
	"ref_cidade": [Vector3(-26.0, 16.0, 46.0), Vector3(12.0, 3.0, -4.0), 60.0],
	"ref_personagem": [POSE_AT + Vector3(-1.6, 1.1, 2.4), POSE_AT + Vector3(0.0, 1.35, 0.0), 40.0],
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
	for node: Node in get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.controller is BotController:
			# Bots fora da foto (longe, parados).
			character.set_physics_process(false)
			character.teleport(Transform3D(Basis.IDENTITY, Vector3(-44.0, 1.05, 12.0)))
	await _frames(10)
	# De fora o jogador aparece inteiro (normalmente o corpo dele é só sombra).
	(player.camera.get_node("ViewModel") as Node3D).visible = false
	player.model.set_shadow_only(false)
	player.set_physics_process(false)
	# Virado para a câmera da foto, em pose de mira.
	player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-150.0)), POSE_AT))
	player.model.update_motion(0.0, 0.0, false)
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	for shot_name: String in SHOTS:
		var spec: Array = SHOTS[shot_name]
		camera.fov = spec[2]
		camera.global_position = spec[0]
		camera.look_at(spec[1])
		await _frames(12)
		_shot(shot_name)
	await _frames(3)
	quit()


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


func _shot(shot_name: String) -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	var path: String = folder.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)
