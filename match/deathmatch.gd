class_name Deathmatch
extends Node
## Modo de jogo "todos contra todos": conta abates e mortes, controla o cronômetro e decide o
## vencedor. Quem decide acertos e mortes é o MatchReferee; este modo só pontua.
##
## Regras: cada abate vale 1 ponto. Cair da ilha conta como morte, mas não dá ponto a ninguém.
## A partida acaba quando o tempo zera ou alguém chega a `score_limit` abates.

signal score_changed
## Alguém morreu. `killer` é null quando foi queda.
signal kill_happened(killer: Character, victim: Character)
signal match_started
## Fim da partida. `ranking`: [{"character", "kills", "deaths"}], do 1º ao último.
signal match_finished(ranking: Array[Dictionary])

const GROUP: StringName = &"game_mode"

@export_range(10.0, 1800.0, 1.0, "suffix:s") var duration: float = 300.0
@export_range(1, 100, 1) var score_limit: int = 15

var time_left: float = 0.0
var is_finished: bool = false

## Placar por personagem: {"kills": int, "deaths": int}.
var _stats: Dictionary[Character, Dictionary] = {}


## Acha o modo de jogo da cena atual (ou null se não houver).
static func find(from: Node) -> Deathmatch:
	return from.get_tree().get_first_node_in_group(GROUP) as Deathmatch


func _ready() -> void:
	add_to_group(GROUP)
	time_left = duration
	# O juiz pode ficar pronto depois de nós: conectamos no fim do quadro.
	_connect_to_referee.call_deferred()


func _connect_to_referee() -> void:
	var referee: MatchReferee = MatchReferee.find(self)
	if referee != null:
		referee.character_died.connect(_on_character_died)


func _physics_process(delta: float) -> void:
	if is_finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		finish()


func get_kills(character: Character) -> int:
	return _stats_of(character)["kills"]


func get_deaths(character: Character) -> int:
	return _stats_of(character)["deaths"]


## Todos os personagens do mais bem colocado ao pior: mais abates, depois menos mortes.
func get_ranking() -> Array[Dictionary]:
	var ranking: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		ranking.append({"character": character, "kills": get_kills(character), "deaths": get_deaths(character)})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kills"] != b["kills"]:
			return a["kills"] > b["kills"]
		if a["deaths"] != b["deaths"]:
			return a["deaths"] < b["deaths"]
		return (a["character"] as Character).display_name < (b["character"] as Character).display_name)
	return ranking


## Posição (1 = primeiro) do personagem no placar atual.
func get_rank(character: Character) -> int:
	var ranking: Array[Dictionary] = get_ranking()
	for i in ranking.size():
		if ranking[i]["character"] == character:
			return i + 1
	return ranking.size()


## Empate no topo: os dois primeiros com os mesmos abates e mortes.
func is_draw() -> bool:
	var ranking: Array[Dictionary] = get_ranking()
	return ranking.size() > 1 and ranking[0]["kills"] == ranking[1]["kills"] \
			and ranking[0]["deaths"] == ranking[1]["deaths"]


## Encerra a partida: congela o jogo (pausa) e avisa o resultado.
func finish() -> void:
	if is_finished:
		return
	is_finished = true
	get_tree().paused = true
	match_finished.emit(get_ranking())


## Começa de novo: zera o placar e o tempo e faz todo mundo renascer.
func restart() -> void:
	get_tree().paused = false
	_stats.clear()
	time_left = duration
	is_finished = false
	var referee: MatchReferee = MatchReferee.find(self)
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		if referee != null:
			referee.respawn_now(node as Character)
	match_started.emit()
	score_changed.emit()


func _on_character_died(victim: Character, killer: Character) -> void:
	if is_finished:
		return
	_stats_of(victim)["deaths"] += 1
	if killer != null and killer != victim:
		_stats_of(killer)["kills"] += 1
	kill_happened.emit(killer, victim)
	score_changed.emit()
	if killer != null and get_kills(killer) >= score_limit:
		finish()


func _stats_of(character: Character) -> Dictionary:
	if not _stats.has(character):
		_stats[character] = {"kills": 0, "deaths": 0}
	return _stats[character]
