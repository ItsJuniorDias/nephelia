extends SceneTree
## Testes automáticos do jogador, dos controles de toque e da fase de teste.
## Simulam toques, arrastos, teclado e mouse e conferem o resultado.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_controls.gd
## Código de saída 0 = tudo passou. Esta pasta não deve ir no jogo exportado.

const LOOK_POS := Vector2(800, 200)
const JOY_POS := Vector2(150, 520)

var _failures: int = 0
var _level: Node3D
var _player: Player
var _touch: TouchControls
var _spawn: Marker3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://levels/test_level.tscn")
	_level = packed.instantiate()
	root.add_child(_level)
	current_scene = _level
	_player = _level.get_node("Player")
	_touch = _player.get_node("TouchControls")
	_spawn = _level.get_node("SpawnPoint")
	_touch.force_visible = true
	print("touch mode: ", TouchControls.is_touch_mode(), "  viewport: ", root.get_visible_rect().size)

	await _test_lands()
	await _test_keyboard_forward()
	await _test_jump()
	await _test_touch_joystick()
	await _test_touch_look()
	await _test_jump_button()
	await _test_multitouch()
	await _test_mouse_fire()
	await _test_fire_button()
	await _test_focus_out()
	await _test_fall_respawn()
	await _test_canceled_touch()
	await _test_stairs()
	await _test_ramp()
	await _test_platform_jump()

	print("RESULT: ", "ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------- helpers

func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", test_name, "  ", detail)
	else:
		_failures += 1
		print("FAIL  ", test_name, "  ", detail)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _reset(at: Vector3 = Vector3.INF, yaw_deg: float = 0.0) -> void:
	var xf: Transform3D = _spawn.global_transform
	if at != Vector3.INF:
		xf = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_player.teleport(xf)
	await _physics(30)


# Eventos entram em pixels da JANELA; o jogo trabalha em coordenadas da viewport
# (no headless a janela é 64x64, esticada para 1152x1152). Convertemos aqui.
func _to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _to_window_delta(v: Vector2) -> Vector2:
	return root.get_final_transform().basis_xform(v)


func _touch_event(index: int, pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _to_window(pos)
	e.pressed = pressed
	e.canceled = canceled
	Input.parse_input_event(e)
	await _frames(2)


func _drag_event(index: int, pos: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _to_window(pos)
	e.relative = _to_window_delta(relative)
	e.screen_relative = _to_window_delta(relative)
	Input.parse_input_event(e)
	await _frames(2)


func _mouse_click(device: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = device
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = _to_window(pos)
	e.global_position = _to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)
	await _frames(2)


func _forward_strength() -> float:
	return Input.get_action_strength("move_forward")


func _yaw_deg() -> float:
	return rad_to_deg(_player.rotation.y)


func _pitch_deg() -> float:
	return rad_to_deg(_player.get_node("Head").rotation.x)


func _button_center(node_name: String) -> Vector2:
	var c: Control = _touch.get_node("Root/" + node_name)
	return c.get_global_rect().get_center()


# ---------------------------------------------------------------- tests

func _test_lands() -> void:
	var landed: bool = false
	for i in 90:
		await physics_frame
		if _player.is_on_floor():
			landed = true
			break
	_check("01 lands on floor", landed, "y=%.2f" % _player.global_position.y)


func _test_keyboard_forward() -> void:
	await _reset()
	var start: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _physics(60)
	Input.action_release("move_forward")
	var moved: Vector3 = _player.global_position - start
	# Spawn olha para -Z: andar para frente diminui z.
	_check("02 keyboard forward 1s", -moved.z > 2.0 and absf(moved.x) < 0.2 and _player.is_on_floor(),
			"dz=%.2f dx=%.2f" % [moved.z, moved.x])
	await _physics(20)


func _test_jump() -> void:
	await _reset()
	var y0: float = _player.global_position.y
	await physics_frame
	Input.action_press("jump")
	await _physics(2)
	Input.action_release("jump")
	var max_y: float = y0
	var landed_again: bool = false
	for i in 90:
		await physics_frame
		max_y = maxf(max_y, _player.global_position.y)
		if i > 10 and _player.is_on_floor():
			landed_again = true
			break
	_check("03 jump rises and lands", max_y - y0 > 0.8 and landed_again, "rise=%.2f landed=%s" % [max_y - y0, landed_again])


func _test_touch_joystick() -> void:
	await _reset()
	var start: Vector3 = _player.global_position
	await _touch_event(0, JOY_POS, true)
	await _drag_event(0, JOY_POS + Vector2(0, -90), Vector2(0, -90))
	var strength: float = _forward_strength()
	await _physics(30)
	var moved: float = start.z - _player.global_position.z
	await _touch_event(0, JOY_POS + Vector2(0, -90), false)
	var released: bool = _forward_strength() == 0.0 and Input.get_action_strength("move_back") == 0.0 \
			and Input.get_action_strength("move_left") == 0.0 and Input.get_action_strength("move_right") == 0.0
	_check("04 touch joystick moves + releases", strength > 0.5 and moved > 0.8 and released,
			"strength=%.2f moved=%.2f released=%s" % [strength, moved, released])


func _test_touch_look() -> void:
	await _reset()
	await _touch_event(1, LOOK_POS, true)
	await _drag_event(1, LOOK_POS + Vector2(100, 0), Vector2(100, 0))
	var yaw: float = _yaw_deg()
	await _drag_event(1, LOOK_POS + Vector2(100, -40), Vector2(0, -40))
	var pitch: float = _pitch_deg()
	await _drag_event(1, LOOK_POS + Vector2(100, -600), Vector2(0, -2000))
	var clamped: float = _pitch_deg()
	await _touch_event(1, LOOK_POS, false)
	_check("05 touch look yaw right / pitch up / clamp", absf(yaw - (-25.0)) < 0.5 and absf(pitch - 10.0) < 0.5 \
			and absf(clamped - 85.0) < 0.01, "yaw=%.2f pitch=%.2f clamped=%.2f" % [yaw, pitch, clamped])


func _test_jump_button() -> void:
	await _reset()
	var y0: float = _player.global_position.y
	var center: Vector2 = _button_center("JumpButton")
	await _touch_event(2, center, true)
	var pressed: bool = Input.is_action_pressed("jump")
	var max_y: float = y0
	for i in 30:
		await physics_frame
		max_y = maxf(max_y, _player.global_position.y)
	await _touch_event(2, center, false)
	_check("06 jump button", pressed and max_y - y0 > 0.5 and not Input.is_action_pressed("jump"),
			"pressed=%s rise=%.2f center=%s" % [pressed, max_y - y0, center])
	await _physics(40)


func _test_multitouch() -> void:
	await _reset()
	await _touch_event(0, JOY_POS, true)
	await _touch_event(1, LOOK_POS, true)
	await _drag_event(0, JOY_POS + Vector2(0, -90), Vector2(0, -90))
	await _drag_event(1, LOOK_POS + Vector2(40, 0), Vector2(40, 0))
	var both: bool = _forward_strength() > 0.5 and absf(_yaw_deg() - (-10.0)) < 0.5
	await _touch_event(1, LOOK_POS + Vector2(40, 0), false)
	var joystick_kept: bool = _forward_strength() > 0.5
	await _touch_event(0, JOY_POS, false)
	_check("07 multi-touch joystick + look", both and joystick_kept and _forward_strength() == 0.0,
			"both=%s kept=%s yaw=%.2f" % [both, joystick_kept, _yaw_deg()])


func _test_mouse_fire() -> void:
	# project.godot: "fire" liga o mouse REAL (device 32), nunca o emulado do toque (-1).
	var cfg: Dictionary = ProjectSettings.get_setting("input/fire")
	var has_real_mouse: bool = false
	for e: InputEvent in cfg["events"]:
		if e is InputEventMouseButton and e.device == InputEvent.DEVICE_ID_MOUSE:
			has_real_mouse = true
	await _mouse_click(InputEvent.DEVICE_ID_EMULATION, Vector2(800, 100), true)
	var emulated_fires: bool = Input.is_action_pressed("fire")
	await _mouse_click(InputEvent.DEVICE_ID_EMULATION, Vector2(800, 100), false)
	await _mouse_click(InputEvent.DEVICE_ID_MOUSE, Vector2(800, 100), true)
	var real_fires: bool = Input.is_action_pressed("fire")
	await _mouse_click(InputEvent.DEVICE_ID_MOUSE, Vector2(800, 100), false)
	# Em modo toque o mouse não atira (evita tiro a cada toque no Mac); fora dele, atira.
	var expected_real: bool = not TouchControls.is_touch_mode()
	_check("08 mouse fire rules", has_real_mouse and not emulated_fires and real_fires == expected_real,
			"cfg_real_mouse=%s emulated=%s real=%s touch_mode=%s" % [has_real_mouse, emulated_fires, real_fires, TouchControls.is_touch_mode()])


func _test_fire_button() -> void:
	var center: Vector2 = _button_center("FireButton")
	await _touch_event(3, center, true)
	var pressed: bool = Input.is_action_pressed("fire")
	await _touch_event(3, center, false)
	_check("09 fire button", pressed and not Input.is_action_pressed("fire"), "center=%s" % center)


func _test_focus_out() -> void:
	await _touch_event(0, JOY_POS, true)
	await _drag_event(0, JOY_POS + Vector2(0, -90), Vector2(0, -90))
	await _touch_event(3, _button_center("FireButton"), true)
	var held: bool = _forward_strength() > 0.5 and Input.is_action_pressed("fire")
	_touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var cleared: bool = _forward_strength() == 0.0 and not Input.is_action_pressed("fire")
	# Um arrasto atrasado do dedo "perdido" não pode voltar a andar.
	await _drag_event(0, JOY_POS + Vector2(0, -80), Vector2(0, 10))
	var still_cleared: bool = _forward_strength() == 0.0
	await _touch_event(0, JOY_POS, false)
	await _touch_event(3, _button_center("FireButton"), false)
	_check("10 focus-out releases everything", held and cleared and still_cleared,
			"held=%s cleared=%s still=%s" % [held, cleared, still_cleared])


func _test_fall_respawn() -> void:
	_player.global_position = Vector3(0, -100, 0)
	_player.velocity = Vector3(3, -20, 0)
	await _physics(3)
	var dist: float = _player.global_position.distance_to(_spawn.global_position)
	var hv: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_check("11 fall respawn", dist < 0.3 and hv < 0.01, "dist=%.2f hv=%.2f" % [dist, hv])


func _test_canceled_touch() -> void:
	await _reset()
	await _touch_event(0, JOY_POS, true)
	await _drag_event(0, JOY_POS + Vector2(0, -90), Vector2(0, -90))
	var before: float = _forward_strength()
	await _touch_event(0, JOY_POS + Vector2(0, -90), false, true)
	_check("12 canceled touch releases", before > 0.5 and _forward_strength() == 0.0, "before=%.2f after=%.2f" % [before, _forward_strength()])


func _test_stairs() -> void:
	# Escada em x=-7, sobe no sentido -Z a partir de z=0 até 0.9 m.
	await _reset(Vector3(-7, 0.05, 2.0))
	Input.action_press("move_forward")
	await _physics(45)
	Input.action_release("move_forward")
	await _physics(10)
	_check("13 walks up the stairs", _player.global_position.y > 0.8, "y=%.2f z=%.2f" % [_player.global_position.y, _player.global_position.z])


func _test_ramp() -> void:
	var ramp: CSGShape3D = _level.get_node("Props/Ramp")
	var meshes: Array = ramp.get_meshes()
	var aabb: AABB = (meshes[0] as Transform3D) * (meshes[1] as Mesh).get_aabb()
	aabb = ramp.global_transform * aabb
	var center_x: float = aabb.get_center().x
	await _reset(Vector3(center_x, 0.05, aabb.end.z + 1.0))
	Input.action_press("move_forward")
	await _physics(70)
	Input.action_release("move_forward")
	await _physics(10)
	_check("14 walks up the 20° ramp", _player.global_position.y > 1.3, "ramp_aabb=%s y=%.2f" % [aabb, _player.global_position.y])


func _test_platform_jump() -> void:
	# Plataforma de 1 m em (0, 0.5, -2), 4x4: pular + andar para frente deve subir nela.
	await _reset(Vector3(0, 0.05, 1.2))
	await physics_frame
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _physics(2)
	Input.action_release("jump")
	await _physics(25)
	Input.action_release("move_forward")
	await _physics(40)
	_check("15 jumps onto the 1 m platform", _player.global_position.y > 0.95 and _player.is_on_floor(),
			"y=%.2f z=%.2f" % [_player.global_position.y, _player.global_position.z])
