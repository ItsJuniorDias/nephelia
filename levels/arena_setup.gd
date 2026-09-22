extends Node
## Aplica à arena o que o jogador escolheu no menu (a dificuldade dos bots) e liga o fundo
## sonoro (vento e música, ver ArenaAmbience).
##
## Fica como nó da fase. Assim a arena continua abrindo sozinha nos testes (com a dificuldade
## que estiver salva) e o menu não precisa saber nada de bots.


func _ready() -> void:
	# Os bots ficam prontos depois deste nó (a ordem da cena manda): espera o fim do quadro.
	_apply.call_deferred()
	add_child(ArenaAmbience.new())


func _apply() -> void:
	var difficulty: BotDifficulty = Settings.difficulty_resource()
	if difficulty == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"bots"):
		var controller := (node as Character).controller as BotController
		if controller != null:
			controller.difficulty = difficulty
