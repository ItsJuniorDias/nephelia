extends SceneTree
## Ferramenta de conferência: fotografa os personagens da Sky Plaza lado a lado (roupa, cabelo,
## chapéu), closes do pescoço (com e sem a roupa) e o jogador em 1ª pessoa.
##   Godot --path . -s res://tools/character_sheet.gd --resolution 1280x720 -- <pasta absoluta>
## Salva <pasta>/<nome>.png. Cada foto espera a janela desenhar quadros novos: com a janela
## escondida o macOS para de desenhar, e antes as fotos saíam repetidas.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const LINE := Vector3(16.0, 0.05, -4.0)
const SPACING: float = 1.1
const ANGLES: Dictionary[String, Array] = {
	"grupo": [Vector3(0.0, 1.2, 5.2), Vector3(0.0, 0.95, 0.0), 40.0],
	"rostos": [Vector3(0.0, 1.62, 2.6), Vector3(0.0, 1.45, 0.0), 38.0],
	"costas": [Vector3(0.0, 1.6, -4.6), Vector3(0.0, 1.0, 0.0), 40.0],
	"tres_quartos": [Vector3(3.2, 1.5, 3.6), Vector3(0.0, 1.0, 0.0), 40.0],
	# Closes do pescoço (a emenda entre a cabeça e a gola da roupa).
	"pescoco_frente": [Vector3(-1.65, 1.62, 1.2), Vector3(-1.65, 1.52, 0.0), 22.0],
	"pescoco_lado": [Vector3(-0.3, 1.58, 0.9), Vector3(-1.65, 1.52, 0.0), 20.0],
	"pescoco_mulher": [Vector3(-0.35, 1.55, 1.1), Vector3(-0.55, 1.47, 0.0), 22.0],
	"peito_mulher_lado": [Vector3(0.35, 1.4, 0.5), Vector3(-0.55, 1.35, 0.0), 24.0],
}

var _characters: Array[Character] = []


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
			(character.controller as BotController).passive = true
		_characters.append(character)
	await _frames(10)
	# De fora o jogador também aparece (normalmente o corpo dele é só sombra), e os braços da
	# 1ª pessoa (que ficam na câmera dele) somem.
	var view_model := player.camera.get_node("ViewModel") as Node3D
	player.model.set_shadow_only(false)
	view_model.visible = false
	for i: int in _characters.size():
		var at: Vector3 = LINE + Vector3((i - (_characters.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		var character: Character = _characters[i]
		character.teleport(Transform3D(Basis(Vector3.UP, PI), at))
		character.set_physics_process(false)
		character.model.update_motion(0.0, 0.0, false)
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	for angle_name: String in ANGLES:
		var spec: Array = ANGLES[angle_name]
		camera.fov = spec[2]
		camera.global_position = LINE + (spec[0] as Vector3)
		camera.look_at(LINE + (spec[1] as Vector3))
		await _frames(12)
		_shot(angle_name)
	# Só o corpo (sem a roupa): mostra o que ficou do corpo original em volta do pescoço.
	var clothes: Array[Node3D] = []
	for character: Character in _characters:
		for node: Node in character.model.skeleton.get_children():
			if node is MeshInstance3D and String(node.name).contains("Peasant"):
				clothes.append(node as Node3D)
				(node as Node3D).visible = false
	for angle_name: String in ["pescoco_frente", "pescoco_lado", "pescoco_mulher"]:
		var spec: Array = ANGLES[angle_name]
		camera.fov = spec[2]
		camera.global_position = LINE + (spec[0] as Vector3)
		camera.look_at(LINE + (spec[1] as Vector3))
		await _frames(8)
		_shot("sem_roupa_" + angle_name)
	for node: Node3D in clothes:
		node.visible = true
	# Jogador em 1ª pessoa, olhando para os outros.
	player.model.set_shadow_only(true)
	view_model.visible = true
	player.set_physics_process(true)
	player.teleport(Transform3D(Basis(Vector3.UP, 0.0), LINE + Vector3(0.0, 0.0, 4.5)))
	player.camera.current = true
	await _frames(12)
	_shot("1a_pessoa")
	# Olhando para cima e para baixo (nada do próprio corpo pode entrar na frente da câmera).
	for pitch: float in [45.0, -45.0]:
		player.apply_look(player.yaw, deg_to_rad(pitch))
		await _frames(10)
		_shot("1a_pessoa_%s" % ("cima" if pitch > 0.0 else "baixo"))
	await _frames(3)
	quit()


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


# A imagem da tela é a do quadro anterior: com a cena parada há quadros, é a mesma.
func _shot(shot_name: String) -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	var path: String = folder.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)
