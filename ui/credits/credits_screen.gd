class_name CreditsScreen
extends Control
## Créditos do jogo (aberto pelas Opções, no menu inicial e na pausa): quem fez, os autores dos
## assets de terceiros (a textura CC-BY do JulioVII EXIGE crédito no jogo) e as licenças do motor
## Godot e das bibliotecas dele, que o próprio motor fornece (`Engine.get_license_text()` etc.).
##
## A lista segue o `CREDITS.md`: ao entrar asset novo, acrescentar aqui também. A tela é montada
## por `tools/make_menus.gd`; o texto é montado aqui, em inglês (o jogo é só em inglês).

signal closed

const GOLD := "#e0b86b"
const CREAM := "#f0dfb3"
const DIM := "#b8ad94"
const TITLE_FONT := "res://assets/fonts/Limelight-Regular.ttf"

## [título da seção, [linhas]]. Linhas em BBCode simples.
const SECTIONS: Array = [
	["A GAME BY", ["Alexandre de Paula Dias Junior"]],
	["MADE WITH", ["Godot Engine (godotengine.org), MIT license: see the engine licenses below."]],
	["3D MODELS AND ANIMATIONS", [
		"Quaternius (quaternius.com): Downtown City MegaKit, Stylized Nature MegaKit, Universal Base "
				+ "Characters, Universal Animation Library, Modular Character Outfits - Fantasy. CC0.",
		"LowPolyAssets: Low Poly Wild West Guns. CC0.",
	]],
	["TEXTURES", [
		"\"Stylized Grass & Dirt\" by JulioVII (juliovii.itch.io/ftpgrass-dirt), licensed under "
				+ "CC BY. Park lawn texture, resized to 1024 px.",
	]],
	["INTERFACE", [
		"Marble and Gold UI Kit by iuliana-u (iuliana-u.itch.io).",
		"Kenney (kenney.nl): Mobile Controls, Crosshair Pack, UI Pack, Particle Pack. CC0.",
	]],
	["SOUND", [
		"Kenney (kenney.nl): Impact Sounds, Interface Sounds. CC0.",
		"SpringySpringo: Gun reload sounds. CC0.",
		"SketchMan3: wind whoosh loop. CC0.",
	]],
	["MUSIC", [
		"\"Maple Leaf Rag\" by Scott Joplin (1899), played by the United States Marine Band (1906). "
				+ "Public domain.",
		"\"Maple Leaf Rag\" piano performance by Zachary Brewster-Geisz. Public domain.",
	]],
	["FONTS", [
		"Limelight by Ania Kruk and Josefin Sans by Santiago Orozco, SIL Open Font License 1.1.",
	]],
	["THANK YOU", ["To every artist who shares their work for free."]],
]

@onready var text: RichTextLabel = $Panel/Rows/Scroll/Text
@onready var scroll: ScrollContainer = $Panel/Rows/Scroll
@onready var back_button: Button = $Panel/Rows/BackButton


func _ready() -> void:
	visible = false
	back_button.pressed.connect(_on_back)
	text.text = build_text()


func open() -> void:
	visible = true
	scroll.scroll_vertical = 0
	back_button.grab_focus()


## O texto inteiro dos créditos, em BBCode (também usado pelos testes).
static func build_text() -> String:
	var lines := PackedStringArray()
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	lines.append("[center][font=%s][font_size=40][color=%s]NEPHELIA[/color][/font_size][/font]" % [TITLE_FONT, GOLD])
	if not version.is_empty():
		lines.append("[color=%s]Version %s[/color]" % [DIM, version])
	lines.append("[/center]")
	for section: Array in SECTIONS:
		lines.append("")
		lines.append(_heading(section[0]))
		for line: String in section[1]:
			lines.append("[color=%s]%s[/color]" % [CREAM, line])
	lines.append("")
	lines.append(_heading("ENGINE LICENSES"))
	lines.append("[font_size=15][color=%s]%s[/color][/font_size]" % [DIM, _engine_licenses()])
	return "\n".join(lines)


static func _heading(title: String) -> String:
	return "[font=%s][font_size=24][color=%s]%s[/color][/font_size][/font]" % [TITLE_FONT, GOLD, title]


# Licença do Godot e das bibliotecas que vêm dentro dele (FreeType, ENet, mbedTLS...), como a
# página "Complying with licenses" do Godot pede.
static func _engine_licenses() -> String:
	var parts := PackedStringArray()
	parts.append("This game uses Godot Engine, available under the following license:")
	parts.append(_escape(Engine.get_license_text()))
	parts.append("Godot Engine also includes these third-party components:")
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component["parts"]:
			var copyright: String = "\n".join(part["copyright"] as PackedStringArray)
			parts.append("%s\n%s\nLicense: %s" % [component["name"], _escape(copyright), part["license"]])
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		parts.append("%s:\n%s" % [license_name, _escape(licenses[license_name])])
	return "\n\n".join(parts)


# Texto de licença pode ter colchetes: não pode virar BBCode.
static func _escape(value: String) -> String:
	return value.replace("[", "[lb]")


func _on_back() -> void:
	visible = false
	closed.emit()
