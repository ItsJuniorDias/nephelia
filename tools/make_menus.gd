extends SceneTree
## Ferramenta: monta as telas de menu (opções, menu inicial e pausa) e salva as cenas.
##   Godot --headless --path . -s res://tools/make_menus.gd
##
## O layout é feito em código para ficar fácil de reajustar (tamanhos pensados para o celular
## em paisagem). Os scripts ficam em `ui/options_menu/`, `ui/main_menu/` e `ui/pause_menu/`.

const OPTIONS_OUT := "res://ui/options_menu/options_menu.tscn"
const MAIN_OUT := "res://ui/main_menu/main_menu.tscn"
const PAUSE_OUT := "res://ui/pause_menu/pause_menu.tscn"

const DIM := Color(0.03, 0.05, 0.08, 0.72)
const PANEL_COLOR := Color(0.09, 0.11, 0.15, 0.93)
const BRASS := Color(0.85, 0.7, 0.38)


func _initialize() -> void:
	_save(_build_options(), OPTIONS_OUT)
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

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override(&"panel", _panel_style())
	_center(panel)
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 18)
	panel.add_child(rows)

	var title := Label.new()
	title.name = "Title"
	title.text = "OPÇÕES"
	title.theme_type_variation = &"Subtitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", BRASS)
	rows.add_child(title)

	_slider_row(rows, "Sensitivity", "SENSIBILIDADE", 0.3, 3.0, 0.05)
	_slider_row(rows, "Buttons", "TAMANHO DOS BOTÕES", 0.7, 1.6, 0.05)
	_slider_row(rows, "Volume", "VOLUME", 0.0, 1.0, 0.05)

	var back := _button("BackButton", "VOLTAR")
	rows.add_child(back)
	_own(root, root)
	return root


func _build_main_menu() -> Control:
	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/main_menu/main_menu.gd"))

	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.07, 0.12, 0.2)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.set_anchors_preset(Control.PRESET_CENTER)
	rows.custom_minimum_size = Vector2(460, 0)
	rows.add_theme_constant_override(&"separation", 16)
	_center(rows)
	root.add_child(rows)

	var title := Label.new()
	title.name = "Title"
	title.text = "NEPHELIA"
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", BRASS)
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "ARENA NAS NUVENS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(&"font_color", Color(0.75, 0.82, 0.9))
	rows.add_child(subtitle)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 24)
	rows.add_child(spacer)

	rows.add_child(_button("PlayButton", "JOGAR"))
	rows.add_child(_button("DifficultyButton", "DIFICULDADE: MÉDIO"))
	rows.add_child(_button("OptionsButton", "OPÇÕES"))
	rows.add_child(_button("QuitButton", "SAIR"))

	var options: Node = (load(OPTIONS_OUT) as PackedScene).instantiate()
	options.name = "OptionsMenu"
	root.add_child(options)
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

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.set_anchors_preset(Control.PRESET_CENTER)
	rows.custom_minimum_size = Vector2(420, 0)
	rows.add_theme_constant_override(&"separation", 16)
	_center(rows)
	screen.add_child(rows)

	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSA"
	title.theme_type_variation = &"Subtitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", BRASS)
	rows.add_child(title)

	rows.add_child(_button("ResumeButton", "CONTINUAR"))
	rows.add_child(_button("OptionsButton", "OPÇÕES"))
	rows.add_child(_button("MenuButton", "MENU PRINCIPAL"))

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
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_color_override(&"font_color", Color(0.95, 0.93, 0.88))
	button.add_theme_color_override(&"font_hover_color", BRASS)
	button.add_theme_color_override(&"font_focus_color", BRASS)
	button.add_theme_stylebox_override(&"normal", _button_style(Color(0.13, 0.16, 0.22, 0.95)))
	button.add_theme_stylebox_override(&"hover", _button_style(Color(0.2, 0.24, 0.32, 0.97)))
	button.add_theme_stylebox_override(&"pressed", _button_style(Color(0.26, 0.22, 0.14, 0.98)))
	button.add_theme_stylebox_override(&"focus", _button_style(Color(0.2, 0.24, 0.32, 0.5)))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.85, 0.7, 0.38, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	return style


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
