extends SceneTree
## Ferramenta de conferência dos efeitos visuais (Vfx): tiro visto de fora (clarão, fumaça,
## poeira), marcas de tiro e de espingarda na parede, tiro em 1ª pessoa, faíscas do gancho no
## trilho, poeira da aterrissagem, a fumaça do corpo sumindo e o anel de quem renasce.
##   Godot --path . -s res://tools/effects_sheet.gd --resolution 1280x720 --always-on-top -- <pasta absoluta>
## Salva <pasta>/<nome>.png (esperando quadros realmente desenhados, como o character_sheet).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
## Parede de prédio no braço leste da praça (face voltada para a rua, x = 10).
const WALL_SPOT := Vector3(10.0, 1.4, -14.0)

var _level: Node3D
var _player: Character
var _bot: Character
var _referee: MatchReferee
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = (load(ARENA) as PackedScene).instantiate()
	root.add_child(_level)
	current_scene = _level
	(_level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	_player = _level.get_node("Player")
	_referee = _level.get_node("MatchReferee")
	for layer: Node in _player.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var bots: Array[Character] = []
	for node: Node in get_nodes_in_group(&"bots"):
		var bot := node as Character
		(bot.controller as BotController).passive = true
		bot.set_physics_process(false)
		bots.append(bot)
	_bot = bots[0]
	# Os outros bots longe da foto.
	for i: int in range(1, bots.size()):
		bots[i].teleport(Transform3D(Basis.IDENTITY, Vector3(-44.0, 1.05, 10.0 + i * 2.0)))
	await _frames(10)
	_camera = Camera3D.new()
	_level.add_child(_camera)

	# 1) Tiro visto de fora: o bot atira na parede.
	var bot_at := Vector3(4.0, 0.05, -14.0)
	_bot.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), bot_at))
	_player.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 10.0)))
	_player.set_physics_process(false)
	_view(Vector3(6.5, 1.7, -10.5), Vector3(7.0, 1.3, -14.0), 55.0)
	await _frames(12)
	_bot_shot(WALL_SPOT)
	await _frames(1)
	_shot("1_tiro_de_fora")
	await _frames(8)
	_shot("2_poeira_e_fumaca")
	# 2) Espingarda: vários chumbos na parede, e as marcas depois que a poeira baixou.
	_bot.weapon.equip(WeaponCatalog.get_weapon(&"shotgun"))
	_bot_shot(WALL_SPOT + Vector3(0.0, 0.2, 1.5))
	await _frames(45)
	_view(Vector3(8.2, 1.5, -13.2), Vector3(10.0, 1.4, -13.5), 50.0)
	await _frames(6)
	_shot("3_marcas")

	# 3) 1ª pessoa: o jogador atira na parede.
	_player.set_physics_process(true)
	_player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(5.0, 0.05, -12.0)))
	_player.camera.current = true
	await _frames(10)
	_player.weapon.tick(0.0, _fire_command())
	await _frames(1)
	_shot("4_1a_pessoa")
	await _frames(10)
	_shot("5_1a_pessoa_fumaca")

	# 4) Faíscas do gancho: o jogador pendurado no trilho sul, deslizando (visto de fora).
	var rail: SkylineRail = _level.get_node("Rails/RailSouth")
	var offset: float = rail.closest_offset(Vector3(-6.0, 10.0, 21.0))
	_player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), rail.point_at(offset) + Vector3.DOWN * Character.RAIL_HANG))
	_player.attach_to_rail(rail, offset)
	_player.model.set_shadow_only(false)
	await _frames(30)
	var hook: Vector3 = _player.global_position + Vector3.UP * Character.RAIL_HANG
	_view(hook + Vector3(-3.0, -1.0, 5.0), hook + Vector3(0.5, -0.9, 0.0), 50.0)
	await _frames(2)
	_shot("6_faiscas_trilho")
	_player.detach_from_rail(Vector3.ZERO)
	_player.model.set_shadow_only(true)
	_player.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 10.0)))

	# 5) Poeira da aterrissagem: o bot cai de 7 m na praça.
	_bot.set_physics_process(true)
	_bot.teleport(Transform3D(Basis.IDENTITY, Vector3(-4.0, 7.0, 6.0)))
	_view(Vector3(-4.0, 1.4, 11.0), Vector3(-4.0, 0.6, 6.0), 55.0)
	for i: int in 400:
		await physics_frame
		if _bot.is_grounded():
			break
	await _frames(4)
	_shot("7_poeira_aterrissagem")

	# 6) Morte e renascimento: o corpo some numa nuvem e o anel aparece no ponto de nascimento.
	_referee.kill(_bot, _player)
	await _frames(30)
	var body: Vector3 = _bot.global_position
	_referee.respawn_now(_bot)
	await _frames(4)
	_view(body + Vector3(0.0, 1.6, 4.5), body + Vector3(0.0, 0.5, 0.0), 55.0)
	await _frames(3)
	_shot("8_corpo_sumindo")
	var spawn: Vector3 = _bot.global_position
	_view(spawn + Vector3(0.0, 2.2, 4.5), spawn + Vector3(0.0, 0.6, 0.0), 55.0)
	await _frames(1)
	_shot("9_anel_renascer")
	await _frames(3)
	quit()


func _bot_shot(target: Vector3) -> void:
	var origin: Vector3 = _bot.head.global_position
	_referee.resolve_shot(_bot, _bot.weapon, origin, (target - origin).normalized(), false)


func _fire_command() -> CharacterCommand:
	var command := CharacterCommand.new()
	command.fire = true
	return command


func _view(from: Vector3, look: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(look)
	_camera.current = true


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


func _shot(shot_name: String) -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	var path: String = folder.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)
