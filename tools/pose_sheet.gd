extends SceneTree
## Ferramenta de conferência: fotografa como cada arma é segurada, em 1ª pessoa e de fora.
##   Godot --path . -s res://tools/pose_sheet.gd --resolution 1024x640 -- <pasta absoluta>
## Salva <pasta>/<nome>.png (cada foto espera a janela desenhar quadros novos) e imprime quanto
## cada braço errou o ponto da arma (IK). Não roda nos testes: precisa de janela.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
## Rua do braço leste da praça: aberta, com prédios ao fundo.
const SPOT := Vector3(16.0, 0.05, -2.0)
const FP_SPOT := Vector3(20.0, 0.05, -4.0)
## Câmeras de fora, em volta do personagem (ele olha para +Z).
const ANGLES: Dictionary[String, Vector3] = {
	"frente": Vector3(0.9, 1.5, 2.0),
	"lado": Vector3(-2.0, 1.4, 0.4),
	"costas": Vector3(-0.8, 1.75, -1.6),
}
const WEAPONS: Array[StringName] = [&"repeater", &"shotgun", &"revolver"]

var _level: Node3D
var _player: Character
var _bot: Character


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_level)
	current_scene = _level
	(_level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	_player = _level.get_node("Player")
	for node: Node in get_nodes_in_group(&"bots"):
		var other := node as Character
		(other.controller as BotController).passive = true
		if _bot == null:
			_bot = other
			# Parado em pé (o bot passivo sai andando; aqui só interessa a pose).
			_bot.walk_speed = 0.0
		else:
			other.global_position = Vector3(0, -200, 0)
	# Fotos limpas: sem HUD, controles de toque nem menu de pausa.
	for layer: Node in _player.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var referee: MatchReferee = _level.get_node("MatchReferee")
	var camera := Camera3D.new()
	camera.fov = 42.0
	_level.add_child(camera)
	await _hold(20)

	for id: StringName in WEAPONS:
		referee.give_weapon(_player, id)
		referee.give_weapon(_bot, id)
		_player.camera.current = true
		await _hold(20)
		_shot("%s_1a_pessoa" % id)
		camera.current = true
		for angle_name: String in ANGLES:
			camera.global_position = SPOT + ANGLES[angle_name]
			camera.look_at(SPOT + Vector3(0.0, 1.25, 0.3))
			await _hold(12)
			_shot("%s_%s" % [id, angle_name])
		_report(id)
		if WeaponCatalog.get_weapon(id).is_two_handed():
			await _reload_shots(id, camera)
	await _hold(3)
	quit()


# No meio da recarga (o movimento é o maior): em 1ª pessoa e de lado.
func _reload_shots(id: StringName, camera: Camera3D) -> void:
	for character: Character in [_player, _bot]:
		_half_reload(character.weapon)
	_player.camera.current = true
	await _hold(2)
	_shot("%s_recarga_1a_pessoa" % id)
	_half_reload(_bot.weapon)
	camera.current = true
	camera.global_position = SPOT + ANGLES["lado"]
	camera.look_at(SPOT + Vector3(0.0, 1.25, 0.3))
	await _hold(2)
	_shot("%s_recarga_lado" % id)
	for character: Character in [_player, _bot]:
		character.weapon.equip(character.weapon.data)


# Põe a arma na metade da recarga (o bot está sem física: o relógio dele não anda sozinho).
func _half_reload(weapon: Weapon) -> void:
	weapon.ammo = 0
	weapon.is_reloading = true
	weapon.set(&"_reload_duration", weapon.reload_time)
	weapon.set(&"_reload_timer", weapon.reload_time * 0.5)


# Espera `frames` quadros. Os dois personagens são postos no lugar só no começo de cada foto:
# teleportar a cada quadro deixaria o corpo "no ar" (pernas na pose de pulo).
func _hold(frames: int) -> void:
	if _player.global_position.distance_to(FP_SPOT) > 0.2:
		_place(_player, FP_SPOT, FP_SPOT + Vector3(-6.0, 1.3, 3.0))
	if _bot.global_position.distance_to(SPOT) > 0.2:
		_place(_bot, SPOT, SPOT + Vector3(0.0, 1.2, 10.0))
		# Sem física o bot não vira nem anda (o modelo continua animando).
		_bot.set_physics_process(false)
	# Quadros DESENHADOS: com a janela escondida o macOS para de desenhar.
	var target: int = Engine.get_frames_drawn() + frames
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


# A imagem da tela é a do quadro anterior: com a cena parada há quadros, é a mesma.
func _shot(shot_name: String) -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	var path: String = folder.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _report(id: StringName) -> void:
	for character: Character in [_player, _bot]:
		var skeleton: Skeleton3D = character.model.skeleton
		var parts: PackedStringArray = []
		for ik_name: String in [GunMount.RIGHT_ARM_IK, GunMount.LEFT_ARM_IK]:
			var ik := skeleton.get_node(ik_name) as WeaponGripModifier
			parts.append("%s active=%s miss=%.3f" % [ik_name, ik.active, ik.miss])
		print("IK %s %s: %s" % [id, character.name, ", ".join(parts)])


func _place(character: Character, at: Vector3, look_at: Vector3) -> void:
	var to: Vector3 = look_at - at
	character.teleport(Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.z)), at))
