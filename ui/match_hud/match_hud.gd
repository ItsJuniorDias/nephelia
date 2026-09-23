class_name MatchHud
extends CanvasLayer
## Informações da partida para o jogador local: cronômetro, posição no placar, lista de abates
## ("You eliminated Bot") e o aviso no centro quando ele derruba alguém.
## Roda mesmo com o jogo pausado (fim de partida): só mostra informação, não muda nada.

const FEED_TIME: float = 5.0
const FEED_MAX_LINES: int = 5
const ELIMINATION_MESSAGE_TIME: float = 1.6
## Últimos segundos: o cronômetro fica avermelhado.
const HURRY_TIME: float = 30.0
const TIMER_COLOR := Color(1.0, 0.97, 0.9)
const HURRY_COLOR := Color(1.0, 0.45, 0.35)

var character: Character
var deathmatch: Deathmatch

var _elimination_timer: float = 0.0

@onready var timer_label: Label = $Root/TimerLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var kill_feed: VBoxContainer = $Root/KillFeed
@onready var elimination_label: Label = $Root/EliminationLabel


func _ready() -> void:
	elimination_label.visible = false


## Chamado pelo HumanController quando a partida já existe na cena.
func setup(for_character: Character, for_deathmatch: Deathmatch) -> void:
	character = for_character
	deathmatch = for_deathmatch
	deathmatch.score_changed.connect(_refresh_score)
	deathmatch.kill_happened.connect(_on_kill_happened)
	deathmatch.match_started.connect(_clear_feed)
	_refresh_score()


func _process(delta: float) -> void:
	if deathmatch == null:
		return
	var seconds: int = ceili(deathmatch.time_left)
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override(&"font_color",
			HURRY_COLOR if deathmatch.time_left <= HURRY_TIME else TIMER_COLOR)
	if _elimination_timer > 0.0:
		_elimination_timer -= delta
		elimination_label.visible = _elimination_timer > 0.0


## Textos da lista de abates, do mais antigo ao mais novo (usado nos testes).
func get_feed_lines() -> Array[String]:
	var lines: Array[String] = []
	for child: Node in kill_feed.get_children():
		if not child.is_queued_for_deletion():
			lines.append((child as Label).text)
	return lines


func _refresh_score() -> void:
	score_label.text = "#%d   %s" % [deathmatch.get_rank(character), count_label(deathmatch.get_kills(character), "kill")]


func _on_kill_happened(killer: Character, victim: Character) -> void:
	var text: String
	if killer == null:
		text = "%s fell" % _name_of(victim)
	else:
		text = "%s eliminated %s" % [_name_of(killer), _name_of(victim)]
	_add_feed_line(text)
	if killer == character and victim != character:
		elimination_label.text = "ELIMINATED %s" % victim.display_name
		elimination_label.visible = true
		_elimination_timer = ELIMINATION_MESSAGE_TIME
		Sounds.play_2d(self, Sounds.KILL_CONFIRM, -3.0)


func _add_feed_line(text: String) -> void:
	var line := Label.new()
	line.text = text
	# Etiqueta preta do kit atrás de cada linha, colada à direita do tamanho do texto.
	line.theme_type_variation = &"HudTag"
	line.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_font_size_override(&"font_size", 20)
	line.add_theme_constant_override(&"outline_size", 6)
	line.add_theme_color_override(&"font_outline_color", Color(0.12, 0.1, 0.09))
	kill_feed.add_child(line)
	if kill_feed.get_child_count() > FEED_MAX_LINES:
		kill_feed.get_child(0).queue_free()
	get_tree().create_timer(FEED_TIME).timeout.connect(line.queue_free)


func _clear_feed() -> void:
	for child: Node in kill_feed.get_children():
		child.queue_free()
	elimination_label.visible = false
	_elimination_timer = 0.0


# No placar e na lista, o jogador local aparece como "You".
func _name_of(someone: Character) -> String:
	return "You" if someone == character else someone.display_name


## "1 kill", "2 kills" (singular e plural certos).
static func count_label(count: int, noun: String) -> String:
	return "%d %s" % [count, noun if count == 1 else noun + "s"]
