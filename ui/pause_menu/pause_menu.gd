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
@onready var resume_button: Button = $Screen/Frame/Rows/ResumeButton
@onready var options_button: Button = $Screen/Frame/Rows/OptionsButton
@onready var menu_button: Button = $Screen/Frame/Rows/MenuButton
@onready var options_menu: OptionsMenu = $Screen/OptionsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen.visible = false
	resume_button.pressed.connect(close)
	options_button.pressed.connect(options_menu.open)
	menu_button.pressed.connect(_on_main_menu)
	options_menu.closed.connect(func() -> void: resume_button.grab_focus())
	Sounds.wire_buttons(screen)


# A ação "pause" vem da tecla (Esc), do controle e do botão de pausa na tela. Como o botão de
# toque aperta a AÇÃO (e não manda um evento), a leitura é aqui, a cada quadro.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		toggle()


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
	# No computador o mouse volta a ficar preso na tela (no toque ele nunca é capturado).
	if not TouchControls.is_touch_mode():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func toggle() -> void:
	if screen.visible:
		close()
	else:
		open()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
