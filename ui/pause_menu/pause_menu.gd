class_name PauseMenu
extends CanvasLayer
## Menu de pausa da partida: continuar, opções e voltar ao menu inicial.
##
## Fica dentro do jogador (como o HUD). Pausa a árvore inteira, mas ele mesmo continua rodando
## (`process_mode` sempre), senão os botões não responderiam.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"

signal opened
signal resumed

@onready var screen: Control = $Screen
@onready var resume_button: Button = $Screen/Rows/ResumeButton
@onready var options_button: Button = $Screen/Rows/OptionsButton
@onready var menu_button: Button = $Screen/Rows/MenuButton
@onready var options_menu: OptionsMenu = $Screen/OptionsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen.visible = false
	resume_button.pressed.connect(close)
	options_button.pressed.connect(options_menu.open)
	menu_button.pressed.connect(_on_main_menu)
	options_menu.closed.connect(func() -> void: resume_button.grab_focus())


func is_open() -> bool:
	return screen.visible


## Abre a pausa (o jogo congela).
func open() -> void:
	if screen.visible:
		return
	screen.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()
	opened.emit()


## Fecha a pausa e volta ao jogo.
func close() -> void:
	if not screen.visible:
		return
	options_menu.visible = false
	screen.visible = false
	get_tree().paused = false
	resumed.emit()


func toggle() -> void:
	if screen.visible:
		close()
	else:
		open()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
