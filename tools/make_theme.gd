extends SceneTree
## Ferramenta: monta o tema da interface (fontes, tamanhos e a arte do Marble and Gold UI Kit) e
## salva em `ui/theme/`.
##   Godot --headless --path . -s res://tools/make_theme.gd
##
## Josefin Sans (geométrica dos anos 1920) em tudo; Limelight (Art Déco) nos títulos, pela
## variação de tipo "Title". O tema é aplicado ao jogo inteiro por `gui/theme/custom` no
## project.godot. A arte (mármore verde, cobre e ouro) vem do Marble and Gold UI Kit (pago, ver
## CREDITS.md); as bordas de cada peça são "nove fatias": só o meio estica.

const BODY_FONT := "res://assets/fonts/JosefinSans-Variable.ttf"
const TITLE_FONT := "res://assets/fonts/Limelight-Regular.ttf"
const KIT := "res://assets/ui/marble_gold/"
const OUT := "res://ui/theme/nephelia_theme.tres"

## Peso da Josefin Sans (fonte variável, de 100 a 700). O padrão dela é o mais fino (100): com o
## contorno escuro dos textos do HUD a letra quase sumia.
const BODY_WEIGHT := 600

## Tamanhos em pixels, pensados para a tela do celular em paisagem.
const BODY_SIZE := 20
const BUTTON_SIZE := 26
const TITLE_SIZE := 72
const SUBTITLE_SIZE := 30
const MENU_ITEM_SIZE := 21

## Cores do kit: creme sobre o mármore escuro, marrom-escuro sobre o ouro.
const CREAM := Color(0.94, 0.87, 0.7)
const LIGHT := Color(1.0, 0.97, 0.9)
const DARK := Color(0.16, 0.1, 0.05)
const GOLD := Color(0.88, 0.72, 0.42)


func _initialize() -> void:
	var body := FontVariation.new()
	body.base_font = load(BODY_FONT)
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BODY_WEIGHT}
	var title: FontFile = load(TITLE_FONT)
	var theme := Theme.new()
	theme.default_font = body
	theme.default_font_size = BODY_SIZE
	theme.set_color(&"font_color", &"Label", CREAM)
	# Botões um pouco maiores: são tocados com o dedão.
	theme.set_font_size(&"font_size", &"Button", BUTTON_SIZE)

	_variation(theme, &"Title", &"Label", title, TITLE_SIZE)
	_variation(theme, &"Subtitle", &"Label", title, SUBTITLE_SIZE)
	_variation(theme, &"TitleButton", &"Button", title, BUTTON_SIZE)
	theme.set_color(&"font_color", &"Title", GOLD)
	theme.set_color(&"font_color", &"Subtitle", GOLD)

	_buttons(theme)
	_menu_items(theme, title)
	_panels(theme)
	_sliders(theme)
	_toggles(theme)
	_dropdowns(theme)
	_text_fields(theme)
	_scrollbars(theme)
	_hud(theme, title)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err: Error = ResourceSaver.save(theme, OUT)
	print("saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# Botão: trapézio de mármore verde; em cima (dedo, foco) e apertado, de ouro.
func _buttons(theme: Theme) -> void:
	for type_name: StringName in [&"Button", &"TitleButton"]:
		theme.set_stylebox(&"normal", type_name, _slice("options_nav_btn_marble_center", 30, 6, 40, 10))
		theme.set_stylebox(&"hover", type_name, _slice("options_nav_btn_gold_center", 30, 6, 40, 10))
		theme.set_stylebox(&"focus", type_name, _slice("options_nav_btn_gold_center", 30, 6, 40, 10))
		theme.set_stylebox(&"pressed", type_name, _slice("options_nav_btn_gold_center", 30, 6, 40, 10,
				Color(0.85, 0.78, 0.66)))
		theme.set_stylebox(&"disabled", type_name, _slice("options_nav_btn_green_center", 30, 6, 40, 10,
				Color(0.7, 0.7, 0.7)))
		theme.set_color(&"font_color", type_name, CREAM)
		theme.set_color(&"font_hover_color", type_name, DARK)
		theme.set_color(&"font_focus_color", type_name, DARK)
		theme.set_color(&"font_pressed_color", type_name, DARK)
		theme.set_color(&"font_hover_pressed_color", type_name, DARK)
		theme.set_color(&"font_disabled_color", type_name, Color(0.6, 0.6, 0.55))


# Itens do menu dentro da janela de cobre do monumento: só o texto; a barra de cobre aparece
# atrás do item em que o dedo (ou o foco) está.
func _menu_items(theme: Theme, font: FontFile) -> void:
	_variation(theme, &"MenuItem", &"Button", font, MENU_ITEM_SIZE)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(10)
	theme.set_stylebox(&"normal", &"MenuItem", empty)
	theme.set_stylebox(&"disabled", &"MenuItem", empty)
	var bar := _slice("mmenu_centerpiece_menu_selection", 24, 12, 24, 10)
	theme.set_stylebox(&"hover", &"MenuItem", bar)
	theme.set_stylebox(&"focus", &"MenuItem", bar)
	theme.set_stylebox(&"pressed", &"MenuItem", _slice("mmenu_centerpiece_menu_selection", 24, 12, 24, 10,
			Color(0.8, 0.72, 0.6)))
	theme.set_color(&"font_color", &"MenuItem", CREAM)
	theme.set_color(&"font_hover_color", &"MenuItem", DARK)
	theme.set_color(&"font_focus_color", &"MenuItem", DARK)
	theme.set_color(&"font_pressed_color", &"MenuItem", DARK)
	theme.set_color(&"font_hover_pressed_color", &"MenuItem", DARK)


# Janelas: moldura de mármore verde com filete dourado e fundo escuro.
func _panels(theme: Theme) -> void:
	var window := _slice("options_window_marble", 52, 52, 64, 56)
	for type_name: StringName in [&"PanelContainer", &"Panel"]:
		theme.set_stylebox(&"panel", type_name, window)
	# Caixa de diálogo e menus que abrem: fundo preto com borda de cobre.
	theme.set_stylebox(&"panel", &"PopupMenu", _slice("options_left_popup_bg", 6, 6, 12, 10))
	theme.set_stylebox(&"panel", &"PopupPanel", _slice("options_left_popup_bg", 6, 6, 12, 10))


# Slider: trilho preto com moldura de cobre, preenchido de laranja, alça quadrada Art Déco.
func _sliders(theme: Theme) -> void:
	var track := _slice("options_slider_bg_gold", 16, 16, 6, 14)
	var fill := _slice("options_slider_fill_04", 6, 6, 0, 0)
	fill.expand_margin_top = -4.0
	fill.expand_margin_bottom = -4.0
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var grabber: Texture2D = load(KIT + "slider_grabber.png")
	theme.set_icon(&"grabber", &"HSlider", grabber)
	theme.set_icon(&"grabber_highlight", &"HSlider", grabber)
	theme.set_icon(&"grabber_disabled", &"HSlider", grabber)
	# Barra de progresso (a vida no HUD): mesmo trilho e mesmo laranja.
	theme.set_stylebox(&"background", &"ProgressBar", track)
	theme.set_stylebox(&"fill", &"ProgressBar", _slice("options_slider_fill_04", 6, 6, 0, 0))


# Caixas de marcar e botões de opção: quadrado e círculo de latão, preenchidos quando marcados.
func _toggles(theme: Theme) -> void:
	for type_name: StringName in [&"CheckBox", &"CheckButton"]:
		theme.set_icon(&"checked", type_name, load(KIT + "check_on.png"))
		theme.set_icon(&"unchecked", type_name, load(KIT + "check_off.png"))
		theme.set_icon(&"radio_checked", type_name, load(KIT + "radio_on.png"))
		theme.set_icon(&"radio_unchecked", type_name, load(KIT + "radio_off.png"))
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(6)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"hover_pressed"]:
			theme.set_stylebox(state, type_name, empty)
		theme.set_color(&"font_color", type_name, CREAM)
		theme.set_color(&"font_hover_color", type_name, LIGHT)
		theme.set_color(&"font_pressed_color", type_name, LIGHT)
		theme.set_color(&"font_focus_color", type_name, LIGHT)


# Lista suspensa: caixa preta com borda dourada e a seta do kit.
func _dropdowns(theme: Theme) -> void:
	var box := _slice("options_dropdown_bg", 6, 6, 14, 8)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		theme.set_stylebox(state, &"OptionButton", box)
	theme.set_icon(&"arrow", &"OptionButton", load(KIT + "options_dropdown_arrow.png"))
	theme.set_color(&"font_color", &"OptionButton", CREAM)
	theme.set_color(&"font_hover_color", &"OptionButton", LIGHT)
	theme.set_color(&"font_focus_color", &"OptionButton", LIGHT)
	theme.set_color(&"font_pressed_color", &"OptionButton", LIGHT)


# Campo de texto (nome, endereço do anfitrião): a mesma caixa preta de borda dourada da lista.
func _text_fields(theme: Theme) -> void:
	var box := _slice("options_dropdown_bg", 6, 6, 14, 8)
	theme.set_stylebox(&"normal", &"LineEdit", box)
	theme.set_stylebox(&"read_only", &"LineEdit", _slice("options_dropdown_bg", 6, 6, 14, 8, Color(1, 1, 1, 0.6)))
	theme.set_stylebox(&"focus", &"LineEdit", _slice("options_dropdown_bg", 6, 6, 14, 8, Color(1.25, 1.15, 0.9)))
	theme.set_color(&"font_color", &"LineEdit", LIGHT)
	theme.set_color(&"font_uneditable_color", &"LineEdit", Color(CREAM, 0.6))
	theme.set_color(&"font_placeholder_color", &"LineEdit", Color(CREAM, 0.45))
	theme.set_color(&"caret_color", &"LineEdit", GOLD)
	theme.set_color(&"selection_color", &"LineEdit", Color(GOLD, 0.35))


# Barra de rolagem: trilho escuro e alça de cobre arredondada.
func _scrollbars(theme: Theme) -> void:
	var body := _slice("scroll_body", 4, 4, 0, 0)
	var bar := _slice("scroll_bar", 9, 9, 0, 0)
	theme.set_stylebox(&"scroll", &"VScrollBar", body)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		theme.set_stylebox(state, &"VScrollBar", bar)


# Textos do HUD: "HudTag" = etiqueta preta inclinada atrás do texto (placar, cronômetro, avisos);
# "HudBanner" = faixa de cobre com letras escuras (anúncio no meio da tela).
func _hud(theme: Theme, font: FontFile) -> void:
	theme.add_type(&"HudTag")
	theme.set_type_variation(&"HudTag", &"Label")
	theme.set_stylebox(&"normal", &"HudTag", _slice("hud_header_entry", 12, 4, 20, 2, Color(1, 1, 1, 0.85)))
	_variation(theme, &"HudBanner", &"Label", font, 26)
	theme.set_stylebox(&"normal", &"HudBanner", _slice("database_window_header_gold", 40, 12, 48, 6))
	theme.set_color(&"font_color", &"HudBanner", DARK)


# Peça do kit em nove fatias: `edge` e `edge_v` = bordas que não esticam (horizontal e vertical);
# `pad` e `pad_v` = espaço até o conteúdo.
func _slice(file: String, edge: float, edge_v: float, pad: float, pad_v: float,
		tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(KIT + file + ".png")
	style.modulate_color = tint
	style.set_texture_margin(SIDE_LEFT, edge)
	style.set_texture_margin(SIDE_RIGHT, edge)
	style.set_texture_margin(SIDE_TOP, edge_v)
	style.set_texture_margin(SIDE_BOTTOM, edge_v)
	style.set_content_margin(SIDE_LEFT, pad)
	style.set_content_margin(SIDE_RIGHT, pad)
	style.set_content_margin(SIDE_TOP, pad_v)
	style.set_content_margin(SIDE_BOTTOM, pad_v)
	return style


# Variação de tipo: um "Label" com o nome "Title" usa a fonte e o tamanho de título.
func _variation(theme: Theme, variation: StringName, base: StringName, font: FontFile, size: int) -> void:
	theme.add_type(variation)
	theme.set_type_variation(variation, base)
	theme.set_font(&"font", variation, font)
	theme.set_font_size(&"font_size", variation, size)
