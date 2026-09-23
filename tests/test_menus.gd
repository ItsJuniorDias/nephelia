extends SceneTree
## Testes do menu inicial, das opções e da pausa.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_menus.gd
## Código de saída 0 = tudo passou. Esta pasta não deve ir no jogo exportado.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const ARENA := "res://levels/skyplaza/skyplaza.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_menu_buttons()
	await _test_difficulty_saves()
	await _test_options_change_settings()
	await _test_play_opens_arena()
	await _test_pause_freezes_and_resumes()
	await _test_difficulty_reaches_bots()
	await _test_lobby_host_and_leave()
	await _test_lobby_shows_why_match_ended()
	await _test_lobby_finds_games()

	print("RESULT: ", "ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", test_name, "  ", detail)
	else:
		_failures += 1
		print("FAIL  ", test_name, "  ", detail)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


# Abre o menu inicial numa árvore limpa.
func _open_menu() -> MainMenu:
	var menu: MainMenu = (load(MAIN_MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _physics(3)
	return menu


func _close(node: Node) -> void:
	node.queue_free()
	await _physics(2)


func _test_menu_buttons() -> void:
	var menu: MainMenu = await _open_menu()
	var buttons: Array[String] = []
	for child: Node in menu.get_node(^"Rows").get_children():
		if child is Button:
			buttons.append((child as Button).text)
	_check("M1 the main menu shows play, multiplayer, difficulty, options and quit", buttons.size() == 5
			and buttons[0] == "PLAY" and buttons[1] == "MULTIPLAYER" and buttons[2].begins_with("DIFFICULTY")
			and buttons[3] == "OPTIONS" and buttons[4] == "QUIT", "botões=%s" % [buttons])
	await _close(menu)


func _test_difficulty_saves() -> void:
	var menu: MainMenu = await _open_menu()
	Settings.set_option(&"difficulty", &"easy")
	menu._refresh_difficulty()
	var before: String = menu.difficulty_button.text
	menu.difficulty_button.pressed.emit()
	await _physics(2)
	# Recarrega do arquivo: a escolha tem que sobreviver a fechar o jogo.
	var chosen: StringName = Settings.difficulty
	Settings.difficulty = &"medium"
	Settings.load_settings()
	_check("M2 the difficulty button cycles and the choice is saved",
			before.ends_with("EASY") and chosen == &"medium" and Settings.difficulty == chosen,
			"antes=%s escolhida=%s salva=%s" % [before, chosen, Settings.difficulty])
	await _close(menu)


func _test_options_change_settings() -> void:
	var menu: MainMenu = await _open_menu()
	var options: OptionsMenu = menu.options_menu
	menu.options_button.pressed.emit()
	await _physics(2)
	var opened: bool = options.visible
	options.sensitivity_slider.value = 2.0
	options.volume_slider.value = 0.3
	await _physics(2)
	var applied: bool = is_equal_approx(Settings.look_sensitivity, 2.0) and is_equal_approx(Settings.volume, 0.3)
	var label: String = options.sensitivity_value.text
	options.back_button.pressed.emit()
	await _physics(2)
	_check("M3 options change and show the settings", opened and applied and label == "200%"
			and not options.visible, "aberta=%s aplicou=%s label=%s" % [opened, applied, label])
	# Deixa como estava para os outros testes.
	Settings.set_option(&"look_sensitivity", 1.0)
	Settings.set_option(&"volume", 0.8)
	await _close(menu)


func _test_play_opens_arena() -> void:
	var menu: MainMenu = await _open_menu()
	menu.play_button.pressed.emit()
	# A troca de cena acontece no fim do quadro; a arena demora alguns quadros para montar.
	await _physics(30)
	var arena: Node = current_scene
	var loaded: bool = arena != null and arena.name == "SkyPlaza" and arena.get_node_or_null(^"Player") != null
	_check("M4 play opens the arena", loaded, "cena=%s" % [arena.name if arena else "nenhuma"])
	if arena != null:
		await _close(arena)


func _test_pause_freezes_and_resumes() -> void:
	var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(arena)
	current_scene = arena
	await _physics(10)
	var pause: PauseMenu = arena.get_node(^"Player/HumanController/PauseMenu")
	pause.open()
	await _physics(2)
	var was_paused: bool = self.paused and pause.is_open()
	# Pausado, o tempo da partida não anda.
	var deathmatch: Deathmatch = arena.get_node(^"Deathmatch")
	var time_before: float = deathmatch.time_left
	await _physics(10)
	var frozen: bool = is_equal_approx(deathmatch.time_left, time_before)
	pause.close()
	await _physics(10)
	var running: bool = not self.paused and deathmatch.time_left < time_before
	_check("M5 pause freezes the match and resume brings it back", was_paused and frozen and running,
			"pausou=%s congelou=%s voltou=%s" % [was_paused, frozen, running])
	await _close(arena)


func _test_difficulty_reaches_bots() -> void:
	Settings.set_option(&"difficulty", &"hard")
	var arena: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(arena)
	current_scene = arena
	await _physics(5)
	var wrong: Array[String] = []
	for node: Node in get_nodes_in_group(&"bots"):
		var controller := (node as Character).controller as BotController
		if controller.difficulty != Settings.difficulty_resource():
			wrong.append(node.name)
	_check("M6 the chosen difficulty reaches the bots", wrong.is_empty(), "errados=%s" % [wrong])
	Settings.set_option(&"difficulty", &"medium")
	await _close(arena)


# Sala do multiplayer: hospedar mostra o endereço e a lista; sozinho não dá para começar; sair
# fecha a sala e volta ao começo.
func _test_lobby_host_and_leave() -> void:
	var menu: MainMenu = await _open_menu()
	var saved_name: String = Settings.player_name
	menu.multiplayer_button.pressed.emit()
	await _physics(2)
	var lobby: Lobby = menu.lobby
	var opened: bool = lobby.is_open() and lobby.host_button.visible and lobby.rooms_title.visible
	lobby.name_edit.text = "Tester"
	lobby.name_edit.text_changed.emit("Tester")
	lobby.host_button.pressed.emit()
	await _physics(3)
	# Sem botão de começar: o anfitrião espera alguém entrar (aí começa sozinho).
	var hosting: bool = Net.is_host() and not lobby.host_button.visible and lobby.info_label.visible \
			and lobby.info_label.text.begins_with("Waiting for a friend") \
			and lobby.get_node_or_null(^"Panel/Rows/StartButton") == null \
			and lobby.get_player_lines().size() >= 1 and lobby.get_player_lines()[0].begins_with("Tester")
	lobby.back_button.pressed.emit()
	await _physics(2)
	var left: bool = not Net.is_online() and lobby.host_button.visible and lobby.is_open()
	lobby.back_button.pressed.emit()
	await _physics(2)
	_check("M7 the lobby hosts a room, waits for a friend and leaves it", opened and hosting and left
			and not lobby.is_open(), "sala=%s" % [lobby.get_player_lines()])
	Settings.set_option(&"player_name", saved_name)
	await _close(menu)


# A partida em rede acabou mal (o anfitrião saiu): o menu abre a sala contando o motivo.
func _test_lobby_shows_why_match_ended() -> void:
	Net.last_error = "The host left the match."
	var menu: MainMenu = await _open_menu()
	var shown: bool = menu.lobby.is_open() and menu.lobby.status_label.visible \
			and menu.lobby.status_label.text == "The host left the match." and Net.last_error.is_empty()
	_check("M8 the menu tells why the network match ended", shown, menu.lobby.status_label.text)
	await _close(menu)


# Ninguém digita endereço: uma sala aberta neste aparelho aparece sozinha na lista, com botão.
func _test_lobby_finds_games() -> void:
	var menu: MainMenu = await _open_menu()
	var saved_roster: Dictionary[int, String] = Net.roster.duplicate()
	Net.roster = {NetTransport.HOST_ID: "Ana"}
	Net.room_id = 4242
	var beacon := LanBeacon.new()
	var listening: bool = beacon.start(Net.DISCOVERY_PORT, NetMessage.PORT) == OK
	menu.lobby.open()
	var until: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and menu.lobby.get_room_buttons().is_empty():
		beacon.poll()
		await process_frame
	var buttons: Array[Button] = menu.lobby.get_room_buttons()
	_check("M9 the lobby finds a game on the Wi-Fi by itself (no address to type)", listening
			and buttons.size() == 1 and buttons[0].text == "JOIN ANA'S GAME  (1/6)"
			and not menu.lobby.searching_label.visible, "botões=%s" % [buttons.map(func(b: Button) -> String: return b.text)])
	beacon.stop()
	Net.roster = saved_roster
	await _close(menu)
