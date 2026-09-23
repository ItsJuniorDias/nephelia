class_name NameTag
extends Label3D
## Nome flutuando sobre a cabeça dos outros personagens no multiplayer, para saber quem é gente e
## quem é bot: jogador de verdade em dourado; bot em cinza, com "BOT" na frente do nome.
## Some com o personagem morto e atrás de paredes (sem "ver através").

const HEIGHT: float = 2.25
const HUMAN_COLOR := Color(1.0, 0.82, 0.42)
const BOT_COLOR := Color(0.78, 0.8, 0.84)
## Some de longe (não polui a tela nem gasta desenho).
const VISIBLE_DISTANCE: float = 45.0
const THEME := "res://ui/theme/nephelia_theme.tres"

var character: Character


## Põe (ou atualiza) a etiqueta de `for_character`.
static func attach(for_character: Character) -> NameTag:
	var tag := for_character.get_node_or_null(^"NameTag") as NameTag
	if tag == null:
		tag = NameTag.new()
		tag.name = "NameTag"
		for_character.add_child(tag)
	tag.setup(for_character)
	return tag


func setup(for_character: Character) -> void:
	if character == null:
		for_character.died.connect(func(_killer: Character) -> void: visible = false)
		for_character.respawned.connect(func() -> void: visible = true)
	character = for_character
	position = Vector3(0.0, HEIGHT, 0.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Mesmo tamanho na tela a qualquer distância (de longe um texto 3D some).
	fixed_size = true
	pixel_size = 0.001
	font_size = 48
	outline_size = 16
	outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	visibility_range_end = VISIBLE_DISTANCE
	var theme := load(THEME) as Theme
	if theme != null:
		font = theme.default_font
	if character.is_bot:
		text = "BOT  %s" % character.display_name
		modulate = BOT_COLOR
		font_size = 40
	else:
		text = character.display_name
		modulate = HUMAN_COLOR
	visible = character.is_alive
