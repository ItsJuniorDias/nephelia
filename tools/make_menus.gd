extends SceneTree
## Ferramenta: monta as telas de menu (opções, sala do multiplayer, menu inicial e pausa) e salva
## as cenas.
##   Godot --headless --path . -s res://tools/make_menus.gd
##
## O layout é feito em código para ficar fácil de reajustar (tamanhos pensados para o celular
## em paisagem). Os scripts ficam em `ui/options_menu/`, `ui/lobby/`, `ui/main_menu/` e
## `ui/pause_menu/`.

const OPTIONS_OUT := "res://ui/options_menu/options_menu.tscn"
const CREDITS_OUT := "res://ui/credits/credits_screen.tscn"
const LOBBY_OUT := "res://ui/lobby/lobby.tscn"
const MAIN_OUT := "res://ui/main_menu/main_menu.tscn"
const PAUSE_OUT := "res://ui/pause_menu/pause_menu.tscn"

const DIM := Color(0.02, 0.03, 0.05, 0.82)
## Arte do Marble and Gold UI Kit (botões, janelas e sliders vêm do tema, ver make_theme.gd).
const KIT := "res://assets/ui/marble_gold/"
## Menu inicial: o monumento de mármore (peça central do kit, 1019 x 1028 no original) com a
## janela de cobre (418 x 618, no ponto (418, 205) do monumento) onde ficam os itens.
const MONUMENT_SCALE := 0.76
const MONUMENT_SIZE := Vector2(1019, 1028)
const WINDOW_AT := Vector2(418, 205)
const WINDOW_SIZE := Vector2(418, 618)


func _initialize() -> void:
	_save(_build_credits(), CREDITS_OUT)
	_save(_build_options(), OPTIONS_OUT)
	_save(_build_lobby(), LOBBY_OUT)
	_save(_build_main_menu(), MAIN_OUT)
	_save(_build_pause(), PAUSE_OUT)
	quit()


# ---------------------------------------------------------------- telas

func _build_options() -> Control:
	var root := Control.new()
	root.name = "OptionsMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/options_menu/options_menu.gd"))
	root.visible = false
	_dim(root)

	# Janela de mármore do kit (o estilo "panel" vem do tema).
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	_center(panel)
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 18)
	panel.add_child(rows)
	_heading(rows, "OPTIONS")

	_slider_row(rows, "Sensitivity", "SENSITIVITY", 0.3, 3.0, 0.05)
	_slider_row(rows, "Buttons", "BUTTON SIZE", 0.7, 1.6, 0.05)
	_slider_row(rows, "Volume", "VOLUME", 0.0, 1.0, 0.05)
	_slider_row(rows, "Music", "MUSIC", 0.0, 1.0, 0.05)
	_check_row(rows, "FunnySounds", "FUNNY SOUNDS")

	rows.add_child(_button("CreditsButton", "CREDITS"))
	var back := _button("BackButton", "BACK")
	rows.add_child(back)
	# Créditos abrem por cima das opções (no menu inicial e na pausa).
	var credits: Node = (load(CREDITS_OUT) as PackedScene).instantiate()
	credits.name = "Credits"
	root.add_child(credits)
	_own(root, root)
	return root


# Créditos: janela de mármore com o texto rolando (autores, licenças) e VOLTAR. O texto é montado
# pelo script (ui/credits/credits_screen.gd).
func _build_credits() -> Control:
	var root := Control.new()
	root.name = "Credits"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/credits/credits_screen.gd"))
	root.visible = false
	_dim(root)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(860, 0)
	_center(panel)
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 14)
	panel.add_child(rows)
	_heading(rows, "CREDITS")

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var text := RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override(&"normal_font_size", 18)
	# O dedo arrastando o texto rola a janela (o texto não "segura" o toque).
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(text)

	rows.add_child(_button("BackButton", "BACK"))
	_own(root, root)
	return root


# Sala do multiplayer: nome, hospedar, salas achadas no Wi-Fi e lista de quem está (a partida
# começa sozinha quando alguém entra). O script (ui/lobby/lobby.gd) mostra e esconde as partes.
func _build_lobby() -> Control:
	var root := Control.new()
	root.name = "Lobby"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/lobby/lobby.gd"))
	root.visible = false
	_dim(root)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	_center(panel)
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 14)
	panel.add_child(rows)
	_heading(rows, "MULTIPLAYER")

	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override(&"separation", 16)
	rows.add_child(name_row)
	var name_label := Label.new()
	name_label.name = "Label"
	name_label.text = "YOUR NAME"
	name_label.custom_minimum_size = Vector2(200, 0)
	name_row.add_child(name_label)
	name_row.add_child(_text_field("NameEdit", "Player"))

	rows.add_child(_button("HostButton", "HOST GAME"))

	# Salas achadas sozinhas no Wi-Fi (sem digitar endereço): um botão por sala, montado no script.
	var rooms_title := Label.new()
	rooms_title.name = "RoomsTitle"
	rooms_title.text = "GAMES ON THIS WI-FI"
	rooms_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rooms_title.add_theme_color_override(&"font_color", Color(0.88, 0.72, 0.42))
	rows.add_child(rooms_title)
	var rooms := VBoxContainer.new()
	rooms.name = "Rooms"
	rooms.add_theme_constant_override(&"separation", 10)
	rows.add_child(rooms)
	var searching := Label.new()
	searching.name = "Searching"
	searching.text = "Searching..."
	searching.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	searching.add_theme_color_override(&"font_color", Color(0.94, 0.87, 0.7, 0.6))
	rows.add_child(searching)

	var info := Label.new()
	info.name = "Info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(info)

	var players := VBoxContainer.new()
	players.name = "Players"
	players.add_theme_constant_override(&"separation", 6)
	rows.add_child(players)

	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)

	rows.add_child(_button("BackButton", "BACK"))
	_own(root, root)
	return root


func _build_main_menu() -> Control:
	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/main_menu/main_menu.gd"))

	# Céu do kit (degradê azul) atrás de tudo: a cidade do jogo flutua nele.
	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = load(KIT + "screen_bg_blue.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	# O monumento de mármore, com a janela de cobre no meio da tela (a base e a ponta podem
	# sair um pouco da tela, para a janela ter espaço para os itens).
	var window_center: Vector2 = (WINDOW_AT + WINDOW_SIZE * 0.5) * MONUMENT_SCALE
	var monument := _picture("Monument", "mmenu_centerpiece_isolated.png")
	_place(monument, -window_center, MONUMENT_SIZE * MONUMENT_SCALE)
	root.add_child(monument)
	var window := _picture("MenuWindow", "mmenu_centerpiece_menu.png")
	_place(window, WINDOW_AT * MONUMENT_SCALE - window_center, WINDOW_SIZE * MONUMENT_SCALE)
	root.add_child(window)

	# Itens dentro da janela: título, subtítulo e os botões separados por filetes de cobre.
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override(&"separation", 6)
	var inner: Vector2 = WINDOW_SIZE * MONUMENT_SCALE - Vector2(36, 48)
	_place(rows, -inner * 0.5, inner)
	root.add_child(rows)

	var title := Label.new()
	title.name = "Title"
	title.text = "NEPHELIA"
	title.theme_type_variation = &"Title"
	title.add_theme_font_size_override(&"font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "ARENA IN THE CLOUDS"
	subtitle.add_theme_font_size_override(&"font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(&"font_color", Color(0.75, 0.85, 0.82))
	rows.add_child(subtitle)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 14)
	rows.add_child(spacer)

	var items: Array[Button] = [_menu_item("PlayButton", "PLAY"),
			_menu_item("MultiplayerButton", "MULTIPLAYER"),
			_menu_item("DifficultyButton", "DIFFICULTY: MEDIUM"), _menu_item("OptionsButton", "OPTIONS"),
			_menu_item("QuitButton", "QUIT")]
	for i: int in items.size():
		rows.add_child(_separator("Separator%d" % i))
		rows.add_child(items[i])
	rows.add_child(_separator("Separator%d" % items.size()))

	var options: Node = (load(OPTIONS_OUT) as PackedScene).instantiate()
	options.name = "OptionsMenu"
	root.add_child(options)
	var lobby: Node = (load(LOBBY_OUT) as PackedScene).instantiate()
	lobby.name = "Lobby"
	root.add_child(lobby)
	_own(root, root)
	return root


func _build_pause() -> CanvasLayer:
	var root := CanvasLayer.new()
	root.name = "PauseMenu"
	root.layer = 50
	root.set_script(load("res://ui/pause_menu/pause_menu.gd"))

	var screen := Control.new()
	screen.name = "Screen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	root.add_child(screen)
	_dim(screen)

	# Janela de mármore do kit com os botões.
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(560, 0)
	_center(frame)
	screen.add_child(frame)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 16)
	frame.add_child(rows)
	_heading(rows, "PAUSED")

	rows.add_child(_button("ResumeButton", "RESUME"))
	rows.add_child(_button("OptionsButton", "OPTIONS"))
	rows.add_child(_button("MenuButton", "MAIN MENU"))

	var options: Node = (load(OPTIONS_OUT) as PackedScene).instantiate()
	options.name = "OptionsMenu"
	screen.add_child(options)
	_own(root, root)
	return root


# ---------------------------------------------------------------- peças

func _dim(parent: Control) -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)


# Linha com nome à esquerda e uma caixa de marcar (liga/desliga) à direita.
func _check_row(parent: VBoxContainer, row_name: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override(&"separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.custom_minimum_size = Vector2(250, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var check := CheckBox.new()
	check.name = "Check"
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(check)


# Linha com nome à esquerda, barra no meio e o valor em porcentagem à direita.
func _slider_row(parent: VBoxContainer, row_name: String, label_text: String,
		minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override(&"separation", 16)
	parent.add_child(row)

	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(240, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value := Label.new()
	value.name = "Value"
	value.text = "100%"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)


func _button(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.theme_type_variation = &"TitleButton"
	button.custom_minimum_size = Vector2(0, 72)
	return button


# Campo de texto que estica na linha (caixa preta de borda dourada, do tema).
func _text_field(field_name: String, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = field_name
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 56)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return field


# Item do menu inicial: só o texto; a barra de cobre aparece atrás quando o dedo está nele.
func _menu_item(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.theme_type_variation = &"MenuItem"
	button.custom_minimum_size = Vector2(0, 50)
	return button


# Filete de cobre entre os itens do menu.
func _separator(separator_name: String) -> TextureRect:
	var line := _picture(separator_name, "mmenu_centerpiece_menu_separator.png")
	line.custom_minimum_size = Vector2(0, 2)
	line.stretch_mode = TextureRect.STRETCH_SCALE
	return line


# Título de janela: letras douradas e, embaixo, a faixa de cobre do kit.
func _heading(parent: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = text
	title.theme_type_variation = &"Subtitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)
	var strip := _picture("TitleStrip", "options_window_header_gold.png")
	strip.custom_minimum_size = Vector2(0, 14)
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(strip)


func _picture(picture_name: String, file: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = picture_name
	picture.texture = load(KIT + file)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


# Põe um controle a `offset` do centro da tela, com `size` (continua no centro em qualquer tela).
func _place(control: Control, offset: Vector2, size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + size.x
	control.offset_bottom = offset.y + size.y


# Centraliza um controle já ancorado no centro (o tamanho vem do conteúdo).
func _center(control: Control) -> void:
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH


# Marca o dono dos nós criados aqui. Cena instanciada (como a tela de opções) recebe dono, mas
# os filhos DELA não: senão a cena é salva duas vezes e aparece duplicada.
func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			_own(child, owner_node)


func _save(node: Node, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var packed := PackedScene.new()
	var err: Error = packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved %s (%s)" % [path, error_string(err)])
	node.free()
