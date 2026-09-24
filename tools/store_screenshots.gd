extends SceneTree
## Ferramenta: prints para a App Store, renderizados já no tamanho que a Apple pede, com o HUD na
## escala do jogo (uma SubViewport do tamanho da tela do aparelho, com o 2D "esticado" como no
## celular: `size_2d_override`).
##   Godot --path . -s res://tools/store_screenshots.gd --resolution 1280x720 --always-on-top -- <pasta absoluta> [preview]
## Salva <pasta>/<aparelho>_<cena>.png. Aparelhos: iPhone 6,9" (2868 x 1320), iPhone 6,5"
## (2778 x 1284; o App Store Connect pode pedir este) e iPad 13" (2752 x 2064), deitados.
## `preview` = só o iPhone, pequeno (para acertar os enquadramentos); o nome de um aparelho
## (ex.: `iphone65`) = só ele.
##
## As cenas são montadas de verdade no jogo (bots parados onde a foto pede, o céu no momento
## escolhido): pôr do sol com tiro, noite com os postes, descida no trilho, menu e as etiquetas
## de nome do multiplayer.

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const PLAYER_LOOK := "res://characters/looks/player.tres"

## [nome, tamanho da imagem, tamanho do 2D (a tela de 648 de altura do jogo, esticada)].
const DEVICES: Array = [
	["iphone69", Vector2i(2868, 1320), Vector2i(1408, 648)],
	["iphone65", Vector2i(2778, 1284), Vector2i(1402, 648)],
	["ipad13", Vector2i(2752, 2064), Vector2i(1152, 864)],
]

var _view: SubViewport
var _out: String = ""
var _device: String = ""
var _level: Node3D
var _player: Character
var _bots: Array[Character] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	var preview: bool = args.size() > 1 and args[1] == "preview"
	_view = SubViewport.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.msaa_3d = Viewport.MSAA_4X
	_view.size_2d_override_stretch = true
	root.add_child(_view)
	if args.size() > 1 and args[1] == "rails":
		await _explore_rails()
		quit()
		return
	var devices: Array = [["preview", Vector2i(1408, 648), Vector2i(1408, 648)]] if preview else DEVICES
	if args.size() > 1 and not preview:
		devices = DEVICES.filter(func(device: Array) -> bool: return device[0] == args[1])
	for device: Array in devices:
		_device = device[0]
		_view.size = device[1]
		_view.size_2d_override = device[2]
		await _menu_shot()
		await _arena_shots()
	quit()


func _menu_shot() -> void:
	var menu: Control = (load(MAIN_MENU) as PackedScene).instantiate()
	_view.add_child(menu)
	await _frames(12)
	_shot("4_menu")
	menu.queue_free()
	await _frames(2)


func _arena_shots() -> void:
	_level = (load(ARENA) as PackedScene).instantiate()
	_view.add_child(_level)
	var deathmatch := _level.get_node("Deathmatch") as Deathmatch
	deathmatch.time_left = 247.0
	_player = _level.get_node("Player")
	(_player.get_node("HumanController/TouchControls") as TouchControls).force_visible = true
	_bots.clear()
	for node: Node in get_nodes_in_group(&"bots"):
		var bot := node as Character
		(bot.controller as BotController).passive = true
		# Parado onde a foto pede (sem andar), mas animado e na física (o tiro acerta).
		bot.set_physics_process(false)
		bot.end_spawn_protection()
		_bots.append(bot)
	await _frames(20)
	var sky := _level.find_child("SkyCycle", true, false) as SkyCycle
	var referee := _level.get_node("MatchReferee") as MatchReferee

	# 1. Pôr do sol, na praça: um bot já caiu (lista de abates) e o jogador atira no outro.
	sky.forced_progress = 0.3
	_player.end_spawn_protection()
	_place(_player, Vector3(0.0, 0.1, 16.0), Vector3(-3.0, 0.1, 6.0))
	_place(_bots[0], Vector3(-3.0, 0.1, 6.0), Vector3(0.0, 0.1, 16.0))
	_place(_bots[1], Vector3(6.0, 0.1, 3.0), Vector3(0.0, 0.1, 16.0))
	_place(_bots[2], Vector3(30.0, 0.1, -30.0), Vector3.ZERO)
	referee.kill(_bots[2], _player)
	referee.apply_damage(_player, 30.0, _bots[1])
	await _frames(100)
	_aim_at(_bots[0])
	await _frames(20)
	Input.action_press(&"fire")
	await _frames(2)
	Input.action_release(&"fire")
	_shot("1_sunset_fight")

	# 2. Noite na rua residencial: postes acesos, estrelas, um bot andando na calçada.
	sky.forced_progress = 0.86
	referee.respawn_now(_bots[2])
	_bots[2].end_spawn_protection()
	_place(_player, Vector3(-42.0, 1.1, -16.0), Vector3(-45.0, 1.1, 2.0))
	_place(_bots[0], Vector3(-44.5, 1.1, -5.0), Vector3(-42.0, 1.1, -16.0))
	_place(_bots[1], Vector3(-40.5, 1.1, 1.0), Vector3(-42.0, 1.1, -16.0))
	_aim_at(_bots[0])
	await _frames(40)
	_shot("2_night_street")

	# 3. Descendo no trilho aéreo, à tarde, com a cidade lá embaixo.
	sky.forced_progress = 0.12
	var rails: Array[Node] = get_nodes_in_group(SkylineRail.GROUP)
	# Trecho escolhido com `rails` (a praça central vista de cima, no sentido contrário do trilho).
	var rail := rails[0] as SkylineRail
	var offset: float = rail.get_length() * 0.6
	_player.teleport(Transform3D(Basis(), rail.point_at(offset) + Vector3.DOWN * Character.RAIL_HANG))
	var forward: Vector3 = -rail.tangent_at(offset)
	_player.apply_look(atan2(-forward.x, -forward.z), deg_to_rad(-25.0))
	_player.attach_to_rail(rail, offset)
	await _frames(20)
	_shot("3_rail_ride")
	_player.detach_from_rail(Vector3.ZERO)

	# 5. Multiplayer: um jogador de verdade (etiqueta dourada) e um bot (etiqueta "BOT").
	sky.forced_progress = 0.05
	var friend: Character = _bots[1]
	friend.look = load(PLAYER_LOOK) as CharacterLook
	friend.is_bot = false
	friend.display_name = "Alex"
	NameTag.attach(friend)
	NameTag.attach(_bots[0])
	_place(_player, Vector3(0.0, 0.1, 16.0), Vector3(0.0, 0.1, 6.0))
	_place(friend, Vector3(-2.2, 0.1, 8.5), Vector3(0.0, 0.1, 16.0))
	_place(_bots[0], Vector3(3.5, 0.1, 5.5), Vector3(0.0, 0.1, 16.0))
	_aim_at(friend)
	await _frames(40)
	_shot("5_multiplayer")

	_level.queue_free()
	await _frames(3)


# Fotos pequenas de vários trechos de trilho (para escolher o da foto da descida).
func _explore_rails() -> void:
	_view.size = Vector2i(704, 324)
	_view.size_2d_override = Vector2i(1408, 648)
	_device = "rail"
	_level = (load(ARENA) as PackedScene).instantiate()
	_view.add_child(_level)
	_player = _level.get_node("Player")
	for layer: Node in _player.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _frames(20)
	var rails: Array[Node] = get_nodes_in_group(SkylineRail.GROUP)
	for i: int in rails.size():
		var rail := rails[i] as SkylineRail
		for fraction: float in [0.3, 0.6]:
			var offset: float = rail.get_length() * fraction
			for direction: float in [1.0, -1.0]:
				var forward: Vector3 = rail.tangent_at(offset) * direction
				_player.teleport(Transform3D(Basis(), rail.point_at(offset) + Vector3.DOWN * Character.RAIL_HANG))
				_player.apply_look(atan2(-forward.x, -forward.z), deg_to_rad(-25.0))
				await _frames(4)
				_shot("%d_%d_%s" % [i, roundi(fraction * 10), "a" if direction > 0 else "b"])


# Põe o personagem em `at`, virado para `facing`.
func _place(character: Character, at: Vector3, facing: Vector3) -> void:
	var to: Vector3 = facing - at
	character.teleport(Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.z)), at))


# O jogador olha para o peito de `target`.
func _aim_at(target: Character) -> void:
	var to: Vector3 = target.global_position + Vector3.UP * 1.25 - _player.head.global_position
	_player.apply_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


# Espera `count` quadros DESENHADOS (não só processados).
func _frames(count: int) -> void:
	var target: int = Engine.get_frames_drawn() + count
	var guard: int = 0
	while Engine.get_frames_drawn() < target and guard < 20000:
		await process_frame
		guard += 1


func _shot(shot_name: String) -> void:
	var path: String = _out.path_join("%s_%s.png" % [_device, shot_name])
	_view.get_texture().get_image().save_png(path)
	print("SHOT ", path)
