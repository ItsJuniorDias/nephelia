class_name MatchResult
extends CanvasLayer
## Tela de fim de partida: vencedor, placar final e "jogar de novo".
## Funciona com o jogo pausado (process_mode = sempre), porque a partida congela ao acabar.
##
## Arte do Marble and Gold UI Kit: janela de "banco de dados" entre colunas de mármore, título
## na faixa de cobre e a linha do jogador com a barra de seleção.

## Barra atrás da linha do jogador local.
const SELECTED: Texture2D = preload("res://assets/ui/marble_gold/database_window_selected.png")
## Largura de cada coluna: posição, nome (estica), abates e mortes.
const COLUMN_WIDTHS: Array[float] = [48.0, 170.0, 96.0, 96.0]
const HEADER_COLOR := Color(0.88, 0.72, 0.42)
const ROW_FONT_SIZE := 22

var character: Character
var deathmatch: Deathmatch
## O placar em texto, uma linha por colocado ("1.  You   2 kills   0 deaths"): testes e registro.
var ranking_lines: PackedStringArray = []

@onready var title_label: Label = $Root/Box/Rows/Title
@onready var table: VBoxContainer = $Root/Box/Rows/Table
@onready var play_again_button: Button = $Root/Box/Rows/PlayAgain


func _ready() -> void:
	visible = false
	play_again_button.pressed.connect(_on_play_again_pressed)
	Sounds.wire_buttons(self)


## Chamado pelo HumanController quando a partida já existe na cena.
func setup(for_character: Character, for_deathmatch: Deathmatch) -> void:
	character = for_character
	deathmatch = for_deathmatch
	deathmatch.match_finished.connect(_on_match_finished)
	deathmatch.match_started.connect(hide)


func _on_match_finished(ranking: Array[Dictionary]) -> void:
	if deathmatch.is_draw():
		title_label.text = "DRAW"
	elif ranking[0]["character"] == character:
		title_label.text = "YOU WIN!"
	else:
		title_label.text = "WINNER: %s" % (ranking[0]["character"] as Character).display_name

	for row: Node in table.get_children():
		table.remove_child(row)
		row.queue_free()
	ranking_lines.clear()
	_add_row(["#", "PLAYER", "KILLS", "DEATHS"], false, true)
	for i in ranking.size():
		var entry: Dictionary = ranking[i]
		var mine: bool = entry["character"] == character
		var who: String = "You" if mine else (entry["character"] as Character).display_name
		ranking_lines.append("%d.  %s   %s   %s" % [i + 1, who, MatchHud.count_label(entry["kills"], "kill"),
				MatchHud.count_label(entry["deaths"], "death")])
		_add_row([str(i + 1), who, str(entry["kills"]), str(entry["deaths"])], mine, false)
	show()
	play_again_button.grab_focus()
	# Sino de fim de partida (a tela roda com o jogo pausado; o som também).
	Sounds.play_2d(self, Sounds.MATCH_END, -2.0)


# Uma linha do placar; a do jogador local ganha a barra de seleção do kit.
func _add_row(cells: Array, highlight: bool, header: bool) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(highlight))
	var columns := HBoxContainer.new()
	row.add_child(columns)
	for i: int in cells.size():
		var label := Label.new()
		label.text = cells[i]
		label.custom_minimum_size.x = COLUMN_WIDTHS[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 1 else HORIZONTAL_ALIGNMENT_CENTER
		if i == 1:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override(&"font_size", 16 if header else ROW_FONT_SIZE)
		if header:
			label.add_theme_color_override(&"font_color", HEADER_COLOR)
		columns.add_child(label)
	table.add_child(row)


func _row_style(highlight: bool) -> StyleBox:
	var style: StyleBox
	if highlight:
		var bar := StyleBoxTexture.new()
		bar.texture = SELECTED
		bar.set_texture_margin_all(20.0)
		style = bar
	else:
		style = StyleBoxEmpty.new()
	style.set_content_margin_all(6.0)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style


func _on_play_again_pressed() -> void:
	deathmatch.restart()
