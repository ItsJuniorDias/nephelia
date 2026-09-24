extends SceneTree
## Ferramenta de conferência: fotografa todas as telas da interface (menu inicial, opções, pausa,
## partida com HUD e controles de toque, jogador levando dano e fim de partida).
##   Godot --path . -s res://tools/ui_sheet.gd --resolution 1280x720 --always-on-top -- <pasta absoluta>
## Salva <pasta>/<nome>.png (esperando quadros realmente desenhados, como o character_sheet).

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const ARENA := "res://levels/skyplaza/skyplaza.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu: Control = (load(MAIN_MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	_shot("1_menu")
	(menu.get_node("OptionsMenu") as OptionsMenu).open()
	await _frames(6)
	_shot("2_opcoes")
	var credits: CreditsScreen = menu.get_node("OptionsMenu/Credits")
	credits.open()
	await _frames(6)
	_shot("2b_creditos")
	credits.scroll.scroll_vertical = 100000
	await _frames(6)
	_shot("2c_creditos_fim")
	credits.visible = false
	menu.lobby.open()
	await _frames(6)
	_shot("2d_multiplayer")
	# Hospedando: lista da sala e o botão START (até 4 pessoas).
	menu.lobby.host_button.pressed.emit()
	await _frames(6)
	_shot("2e_multiplayer_sala")
	menu.lobby.back_button.pressed.emit()
	await _frames(2)
	menu.lobby.visible = false
	menu.queue_free()
	await _frames(2)

	var level: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var deathmatch := level.get_node("Deathmatch") as Deathmatch
	deathmatch.time_left = 3600.0
	for node: Node in get_nodes_in_group(&"bots"):
		((node as Character).controller as BotController).passive = true
	var player: Character = level.get_node("Player")
	var touch: TouchControls = player.get_node("HumanController/TouchControls")
	touch.force_visible = true
	await _frames(20)
	# Um pouco de placar e de dano para o HUD ter o que mostrar.
	var referee: MatchReferee = level.get_node("MatchReferee")
	var bots: Array[Node] = get_nodes_in_group(&"bots")
	referee.kill(bots[0] as Character, player)
	referee.apply_damage(player, 35.0, bots[1] as Character)
	await _frames(12)
	_shot("3_partida_hud")

	var pause: PauseMenu = player.get_node("HumanController/PauseMenu")
	pause.open()
	await _frames(6)
	_shot("4_pausa")
	pause.get_node("Screen/OptionsMenu").call(&"open")
	await _frames(6)
	_shot("5_pausa_opcoes")
	pause.close()
	await _frames(4)

	deathmatch.finish()
	await _frames(8)
	_shot("6_fim_de_partida")
	quit()


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
