class_name TouchControls
extends CanvasLayer
## Controles de toque: joystick flutuante (mover), arrastar para olhar e botões de ação.
##
## Os dedos são distribuídos aqui, em _input(), e não no _gui_input dos Controls,
## porque o _gui_input não entrega bem vários dedos ao mesmo tempo (multitoque).

## Emitido quando um dedo de "olhar" se move. `relative` está em pixels da viewport.
signal look_dragged(relative: Vector2)

# Girar o celular 180° troca o lado do notch sem mudar o tamanho da tela
# (não há size_changed), então conferimos a área segura de tempos em tempos.
const SAFE_AREA_CHECK_INTERVAL: float = 0.5

## Mostra os controles mesmo sem tela de toque (testes / depuração no PC).
@export var force_visible: bool = false:
	set(value):
		force_visible = value
		if is_node_ready():
			_apply_active()

## Desligado = controles somem e soltam tudo (ex.: na tela de fim de partida).
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_active()

## Fração esquerda da tela onde um dedo novo faz nascer o joystick.
@export_range(0.2, 0.6, 0.01) var joystick_zone_ratio: float = 0.4

# Dono de cada dedo (índice do toque -> nó): o joystick, um botão ou `self` (= dedo de olhar).
var _finger_owners: Dictionary[int, Node] = {}
var _buttons: Array[TouchActionButton] = []
var _last_safe_area: Rect2i = Rect2i()
var _safe_area_timer: float = 0.0

@onready var _root: Control = $Root
@onready var _joystick: TouchJoystick = $Root/Joystick


## Verdadeiro em celular/tablet. No PC também é verdadeiro quando
## "Emulate Touch From Mouse" está ligado (para testar o toque com o mouse).
static func is_touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()


func _ready() -> void:
	for child: Node in _root.get_children():
		if child is TouchActionButton:
			_buttons.append(child as TouchActionButton)
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	if is_touch_mode():
		_remove_mouse_buttons_from_action(&"fire")
	_apply_active()


func _exit_tree() -> void:
	release_all()


func _notification(what: int) -> void:
	# Ao perder o foco (ligação, notificação, pause...) os dedos somem sem evento
	# de soltar; sem isto o jogador continuaria andando ou atirando sozinho.
	if what in [
		NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_WINDOW_FOCUS_OUT,
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_PAUSED,
	]:
		release_all()


func _process(delta: float) -> void:
	_safe_area_timer -= delta
	if _safe_area_timer > 0.0:
		return
	_safe_area_timer = SAFE_AREA_CHECK_INTERVAL
	if is_touch_mode() and DisplayServer.get_display_safe_area() != _last_safe_area:
		_apply_safe_area()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_finger_down(touch.index, touch.position)
		else:
			# Soltou ou foi cancelado (ex.: o sistema "roubou" o toque).
			_on_finger_up(touch.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		_on_finger_drag(screen_drag.index, screen_drag.position, screen_drag.relative)
		get_viewport().set_input_as_handled()


## Solta todos os dedos e todas as ações apertadas pelos controles de toque.
func release_all() -> void:
	_finger_owners.clear()
	if _joystick != null:
		_joystick.end()
	for button: TouchActionButton in _buttons:
		button.release()


func _on_finger_down(finger: int, at: Vector2) -> void:
	# Toque repetido no mesmo dedo (perdemos o "soltar"): solta o dono antigo primeiro.
	if _finger_owners.has(finger):
		_on_finger_up(finger)

	for button: TouchActionButton in _buttons:
		if button.is_visible_in_tree() and button.contains_point(at):
			_finger_owners[finger] = button
			button.press()
			return

	var zone_width: float = get_viewport().get_visible_rect().size.x * joystick_zone_ratio
	if at.x < zone_width and not _joystick.is_active():
		_finger_owners[finger] = _joystick
		_joystick.begin(finger, at)
		return

	_finger_owners[finger] = self


func _on_finger_drag(finger: int, at: Vector2, relative: Vector2) -> void:
	var finger_owner: Node = _finger_owners.get(finger, null)
	if finger_owner == _joystick:
		_joystick.drag(at)
	elif finger_owner == self:
		look_dragged.emit(relative)
	# Botões ignoram o arrasto: continuam apertados até o dedo sair da tela.


func _on_finger_up(finger: int) -> void:
	if not _finger_owners.has(finger):
		return
	var finger_owner: Node = _finger_owners[finger]
	_finger_owners.erase(finger)
	if finger_owner == _joystick:
		_joystick.end()
	elif finger_owner is TouchActionButton:
		# Dois dedos no mesmo botão: só solta quando o último sair.
		if not _finger_owners.values().has(finger_owner):
			(finger_owner as TouchActionButton).release()


# No modo toque, atirar é só pelo botão FIRE. No Mac (testando com "Emulate Touch From
# Mouse") cada clique vira um toque E um clique de mouse; sem isto, arrastar o dedo para
# olhar também atiraria. Só muda o Input Map enquanto o jogo roda, não o project.godot.
func _remove_mouse_buttons_from_action(action: StringName) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			InputMap.action_erase_event(action, event)


# Liga os controles só em modo toque (ou se forçado); desligados, não seguram nenhuma ação.
func _apply_active() -> void:
	var active: bool = enabled and (force_visible or is_touch_mode())
	visible = active
	set_process_input(active)
	set_process(active)
	if active:
		_apply_safe_area()
	else:
		release_all()


func _on_visibility_changed() -> void:
	if not visible:
		release_all()


# Afasta os controles do notch e dos cantos arredondados do celular.
func _apply_safe_area() -> void:
	if _root == null:
		return
	var left: float = 0.0
	var top: float = 0.0
	var right: float = 0.0
	var bottom: float = 0.0

	if is_touch_mode():
		_last_safe_area = DisplayServer.get_display_safe_area()
		var window: Window = get_window()
		var window_rect := Rect2(Vector2(window.position), Vector2(window.size))
		# A área segura vem em pixels da TELA; recortamos pela janela do jogo
		# (no PC a janela pode estar em qualquer lugar, ou até em outro monitor).
		var safe_rect: Rect2 = Rect2(_last_safe_area).intersection(window_rect)
		if safe_rect.has_area():
			# Pixels da janela -> coordenadas da viewport (base 1152x648 esticada).
			var to_viewport: Vector2 = get_viewport().get_visible_rect().size / window_rect.size
			left = (safe_rect.position.x - window_rect.position.x) * to_viewport.x
			top = (safe_rect.position.y - window_rect.position.y) * to_viewport.y
			right = (window_rect.end.x - safe_rect.end.x) * to_viewport.x
			bottom = (window_rect.end.y - safe_rect.end.y) * to_viewport.y

	# Root usa âncoras de tela cheia, então os offsets funcionam como margens.
	_root.offset_left = left
	_root.offset_top = top
	_root.offset_right = -right
	_root.offset_bottom = -bottom
