class_name MainMenu
extends Control
## Menu inicial: jogar contra bots, multiplayer, escolher a dificuldade, opções e sair.
##
## É a primeira cena do jogo. "PLAY" troca para a arena; a dificuldade escolhida fica salva em
## `Settings` e a arena a aplica aos bots ao abrir. "MULTIPLAYER" abre a sala (ui/lobby).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"

@onready var play_button: Button = $Rows/PlayButton
@onready var multiplayer_button: Button = $Rows/MultiplayerButton
@onready var difficulty_button: Button = $Rows/DifficultyButton
@onready var options_button: Button = $Rows/OptionsButton
@onready var quit_button: Button = $Rows/QuitButton
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var lobby: Lobby = $Lobby


func _ready() -> void:
	# No menu o dedo/mouse precisa aparecer (na partida o mouse é capturado).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(start_match)
	multiplayer_button.pressed.connect(open_lobby)
	difficulty_button.pressed.connect(_on_difficulty)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	options_menu.closed.connect(func() -> void: play_button.grab_focus())
	lobby.closed.connect(func() -> void: multiplayer_button.grab_focus())
	# No celular não existe "sair": o sistema é que fecha o aplicativo.
	quit_button.visible = not OS.has_feature("mobile")
	_refresh_difficulty()
	play_button.grab_focus()
	# Ragtime de 1906 (banda dos Fuzileiros dos EUA, domínio público) e clique nos botões.
	Sounds.music(self, Sounds.MUSIC_MENU, -6.0)
	Sounds.wire_buttons(self)
	# Voltou de uma partida em rede: a conexão acaba aqui. Se ela acabou mal (o anfitrião saiu),
	# a sala abre contando o motivo.
	var reason: String = Net.last_error
	if Net.is_online():
		Net.stop()
	Net.last_error = ""
	if not reason.is_empty():
		lobby.open(reason)


## Começa a partida na arena (também usado pelos testes).
func start_match() -> void:
	get_tree().change_scene_to_file(ARENA)


## Abre a sala do multiplayer.
func open_lobby() -> void:
	lobby.open()


func _on_difficulty() -> void:
	Settings.next_difficulty()
	_refresh_difficulty()


func _on_options() -> void:
	options_menu.open()


func _on_quit() -> void:
	get_tree().quit()


func _refresh_difficulty() -> void:
	difficulty_button.text = "DIFFICULTY: %s" % Settings.difficulty_label()
