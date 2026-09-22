extends SceneTree
## Ferramenta: monta o tema da interface (fontes e tamanhos) e salva em `ui/theme/`.
##   Godot --headless --path . -s res://tools/make_theme.gd
##
## Josefin Sans (geométrica dos anos 1920) em tudo; Limelight (Art Déco) nos títulos, pela
## variação de tipo "Title". O tema é aplicado ao jogo inteiro por
## `gui/theme/custom` no project.godot.

const BODY_FONT := "res://assets/fonts/JosefinSans-Variable.ttf"
const TITLE_FONT := "res://assets/fonts/Limelight-Regular.ttf"
const OUT := "res://ui/theme/nephelia_theme.tres"

## Tamanhos em pixels, pensados para a tela do celular em paisagem.
const BODY_SIZE := 20
const BUTTON_SIZE := 26
const TITLE_SIZE := 72
const SUBTITLE_SIZE := 30


func _initialize() -> void:
	var body: FontFile = load(BODY_FONT)
	var title: FontFile = load(TITLE_FONT)
	var theme := Theme.new()
	theme.default_font = body
	theme.default_font_size = BODY_SIZE
	# Botões um pouco maiores: são tocados com o dedão.
	theme.set_font_size(&"font_size", &"Button", BUTTON_SIZE)

	_variation(theme, &"Title", &"Label", title, TITLE_SIZE)
	_variation(theme, &"Subtitle", &"Label", title, SUBTITLE_SIZE)
	_variation(theme, &"TitleButton", &"Button", title, BUTTON_SIZE)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err: Error = ResourceSaver.save(theme, OUT)
	print("saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# Variação de tipo: um "Label" com o nome "Title" usa a fonte e o tamanho de título.
func _variation(theme: Theme, variation: StringName, base: StringName, font: FontFile, size: int) -> void:
	theme.add_type(variation)
	theme.set_type_variation(variation, base)
	theme.set_font(&"font", variation, font)
	theme.set_font_size(&"font_size", variation, size)
