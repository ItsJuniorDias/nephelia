extends Node
## Aplica à arena o que o jogador escolheu no menu (a dificuldade dos bots), liga o fundo
## sonoro (vento e música, ver ArenaAmbience), o céu da tarde à noite (SkyCycle) e, no
## multiplayer, a partida em rede (NetHost no anfitrião, NetClient nos outros).
##
## Fica como nó da fase. Assim a arena continua abrindo sozinha nos testes (com a dificuldade
## que estiver salva) e o menu não precisa saber nada de bots.


func _ready() -> void:
	# Os bots ficam prontos depois deste nó (a ordem da cena manda): espera o fim do quadro.
	_apply.call_deferred()
	add_child(ArenaAmbience.new())
	# Céu da tarde à noite conforme a partida passa (e os postes acendem).
	add_child(SkyCycle.new())
	# Multiplayer: quem hospeda decide tudo; quem entrou manda comandos e mostra o que chega.
	var net_game: NetGame = null
	if Net.is_host():
		net_game = NetHost.new()
		net_game.name = "NetHost"
	elif Net.is_client():
		net_game = NetClient.new()
		net_game.name = "NetClient"
	if net_game != null:
		net_game.level = get_parent()
		add_child(net_game)


func _apply() -> void:
	var difficulty: BotDifficulty = Settings.difficulty_resource()
	if difficulty == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"bots"):
		var controller := (node as Character).controller as BotController
		if controller != null:
			controller.difficulty = difficulty
