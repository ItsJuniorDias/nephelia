class_name MatchResult
extends CanvasLayer
## Tela de fim de partida: vencedor, placar final e "jogar de novo".
## Funciona com o jogo pausado (process_mode = sempre), porque a partida congela ao acabar.

var character: Character
var deathmatch: Deathmatch

@onready var title_label: Label = $Root/Box/Title
@onready var ranking_label: Label = $Root/Box/Ranking
@onready var play_again_button: Button = $Root/Box/PlayAgain


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

	var lines: PackedStringArray = []
	for i in ranking.size():
		var entry: Dictionary = ranking[i]
		var who: String = "You" if entry["character"] == character else (entry["character"] as Character).display_name
		lines.append("%d.  %s   %s   %s" % [i + 1, who, MatchHud.count_label(entry["kills"], "kill"),
				MatchHud.count_label(entry["deaths"], "death")])
	ranking_label.text = "\n".join(lines)
	show()
	play_again_button.grab_focus()
	# Sino de fim de partida (a tela roda com o jogo pausado; o som também).
	Sounds.play_2d(self, Sounds.MATCH_END, -2.0)


func _on_play_again_pressed() -> void:
	deathmatch.restart()
