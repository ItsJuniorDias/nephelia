extends SceneTree
## Ferramenta de conferência do multiplayer: fotografa o menu, a sala (sozinho, hospedando com um
## amigo, entrando na sala de outro), a partida vista pelo cliente com as etiquetas de nome (gente
## em dourado, bot em cinza) e o fim de partida no cliente. Abre outros processos do Godot sem
## tela para fazer o papel dos outros aparelhos (tools/net_sheet_peer.gd e tests/net_host_runner.gd).
##   Godot --path . -s res://tools/net_sheet.gd --resolution 1280x720 --always-on-top -- <pasta absoluta>
## Salva <pasta>/<nome>.png.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const FRIEND_PORT: int = 24811

var _processes: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# A sala salva o nome: guarda o do jogador e devolve no fim.
	var saved_name: String = Settings.player_name
	var menu: MainMenu = (load(MAIN_MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	_shot("1_menu")
	menu.open_lobby()
	await _frames(6)
	_shot("2_sala")

	# Hospedando: esperando alguém; depois um amigo entra (outro processo) e a contagem começa.
	var lobby: Lobby = menu.lobby
	Net.host_lan(Settings.player_name, FRIEND_PORT)
	lobby._open_room()
	lobby._room.auto_start_delay = 3.4
	await _frames(6)
	_shot("3_sala_anfitriao_esperando")
	_spawn(["-s", "res://tools/net_sheet_peer.gd", "--", str(FRIEND_PORT), "Beatriz", "25"])
	await _until(func() -> bool: return Net.roster.size() >= 2, 25000)
	await _frames(8)
	_shot("3_sala_anfitriao_contagem")
	lobby._on_back()
	await _frames(4)

	# Entrando na sala de outro aparelho: ela aparece sozinha na lista (sem digitar endereço).
	var report: String = ProjectSettings.globalize_path("user://net_sheet_host.json")
	_spawn(["-s", "res://tests/net_host_runner.gd", "--", str(NetMessage.PORT), report, "90", "4", "beacon"])
	await _until(func() -> bool: return not lobby.get_room_buttons().is_empty(), 25000)
	await _frames(6)
	_shot("4_sala_achou_jogo")
	var level: Node = null
	if not lobby.get_room_buttons().is_empty():
		lobby.get_room_buttons()[0].pressed.emit()
	await _until(func() -> bool: return Net.is_client() and Net.roster.size() >= 2, 10000)
	await _frames(6)
	_shot("4_sala_cliente")
	await _until(func() -> bool: return current_scene is Node3D, 15000)
	level = current_scene
	await _until(func() -> bool:
		var found := level.find_child("NetClient", true, false) as NetClient
		return found != null and found.has_world and not (level.get_node("Deathmatch") as Deathmatch).waiting,
		20000)
	var client := level.find_child("NetClient", true, false) as NetClient
	await _frames(40)
	_shot("5_partida_cliente")

	# Etiquetas de nome: câmera perto de um jogador de verdade e de um bot.
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	for id: int in client.characters:
		var character: Character = client.character_of(id)
		if character == null or character == client.local:
			continue
		var head: Vector3 = character.global_position + Vector3.UP * 1.9
		# De frente (o personagem olha para -Z), a 5 m.
		camera.global_position = head - character.global_basis.z * 5.0 + Vector3.UP * 0.4
		camera.look_at(head)
		await _frames(6)
		_shot("6_etiqueta_%s" % ("bot_" if character.is_bot else "jogador_") + character.display_name.to_lower())
	camera.queue_free()
	client.local.camera.current = true

	(level.get_node("Deathmatch") as Deathmatch).finish()
	await _frames(8)
	_shot("7_fim_cliente")

	Net.stop()
	Settings.set_option(&"player_name", saved_name)
	for pid: int in _processes:
		if OS.is_process_running(pid):
			OS.kill(pid)
	quit()


func _spawn(args: Array[String]) -> void:
	var full: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	_processes.append(OS.create_process(OS.get_executable_path(), full))


func _until(condition: Callable, timeout_ms: int) -> bool:
	var until: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await process_frame
	return condition.call()


# Espera `count` quadros DESENHADOS (não só processados). A árvore pode estar pausada.
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
