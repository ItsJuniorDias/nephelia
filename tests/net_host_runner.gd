extends SceneTree
## Anfitrião de teste para o `tests/test_net.gd`: roda em OUTRO processo do Godot (sem tela),
## abre a sala, espera um cliente, começa a partida e fica andando em círculo com o próprio
## personagem (os bots ficam passivos). Quando o cliente sai, confere se um bot voltou para a
## vaga, grava um relatório (JSON) e fecha.
##   Godot --headless --path . -s res://tests/net_host_runner.gd -- <porta> <relatório.json> <segundos>
##       [espera antes de começar, em segundos]

const ARENA := "res://levels/skyplaza/skyplaza.tscn"

var _report: Dictionary = {"started": false, "client_joined": false, "client_left": false,
		"bots_after_leave": -1, "characters_with_client": -1, "remote_positions": []}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var port: int = args[0].to_int()
	var report_path: String = args[1]
	var seconds: float = args[2].to_float()
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)

	Settings.player_name = "HostBot"
	if Net.host_lan("HostBot", port) != OK:
		_finish(report_path, "could not open the room")
		return
	var lobby := NetLobby.new()
	root.add_child(lobby)
	while Net.roster.size() < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	if Net.roster.size() < 2:
		_finish(report_path, "nobody joined")
		return
	_report["client_joined"] = true
	var start_delay: float = args[3].to_float() if args.size() > 3 else 0.0
	var start_at: int = Time.get_ticks_msec() + int(start_delay * 1000.0)
	while Time.get_ticks_msec() < start_at:
		await process_frame
	lobby.start_match()
	lobby.queue_free()

	var level: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	await physics_frame
	var host: NetHost = level.find_child("NetHost", true, false) as NetHost
	for node: Node in get_nodes_in_group(&"bots"):
		((node as Character).controller as BotController).passive = true
	var deathmatch := level.get_node("Deathmatch") as Deathmatch
	_report["shots"] = []
	(level.get_node("MatchReferee") as MatchReferee).shot_resolved.connect(func(result: ShotResult) -> void:
		if result.shooter != host.local_character:
			_report["shots"].append([result.shooter.display_name, result.hit,
					result.victim.display_name if result.victim != null else "", result.damage,
					[result.end_point.x, result.end_point.y, result.end_point.z]]))

	# Anda em círculo: para frente o tempo todo, virando devagar.
	Input.action_press(&"move_forward")
	var client_peer: int = 0
	for peer: int in host.players:
		client_peer = peer
	var target_placed: bool = false
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if not deathmatch.waiting:
			_report["started"] = true
			deathmatch.time_left = maxf(deathmatch.time_left, 600.0)
			# Alvo do teste de tiro: o primeiro bot, parado a 6 m na frente do cliente.
			if not target_placed and host.players.has(client_peer):
				target_placed = true
				_place_target(host, host.players[client_peer]["character"])
		if host.local_character != null and host.local_character.is_alive:
			host.local_character.apply_look(host.local_character.yaw + 0.02, 0.0)
		# Bots que entram depois também ficam passivos.
		for node: Node in get_nodes_in_group(&"bots"):
			((node as Character).controller as BotController).passive = true
		if host.players.has(client_peer):
			_report["characters_with_client"] = host.characters.size()
			var remote: Character = host.players[client_peer]["character"]
			if is_instance_valid(remote) and Engine.get_physics_frames() % 30 == 0:
				_report["remote_positions"].append([remote.global_position.x, remote.global_position.z])
				_report["starved"] = (remote.controller as RemoteController).starved
				_report["dropped"] = (remote.controller as RemoteController).dropped
				_report["max_queue"] = maxi(_report.get("max_queue", 0), (remote.controller as RemoteController).queued())
		elif _report["client_joined"] and not _report["client_left"]:
			_report["client_left"] = true
			await physics_frame
			var bots: int = 0
			for id: int in host.characters:
				var character: Character = host.character_of(id)
				if character != null and character.controller is BotController:
					bots += 1
			_report["bots_after_leave"] = bots
			break
	Input.action_release(&"move_forward")
	_finish(report_path, "")


func _place_target(host: NetHost, client_character: Character) -> void:
	for id: int in host.characters:
		var bot: Character = host.character_of(id)
		if bot == null or not bot.controller is BotController:
			continue
		var forward: Vector3 = -client_character.global_basis.z
		bot.teleport(Transform3D(Basis(Vector3.UP, client_character.yaw + PI),
				client_character.global_position + forward * 6.0))
		# Parado, mas ainda na física (senão o tiro atravessa). Parado, a proteção de nascimento
		# não acabaria sozinha.
		bot.end_spawn_protection()
		bot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		_report["target"] = bot.display_name
		_report["target_at"] = [bot.global_position.x, bot.global_position.y, bot.global_position.z]
		_report["client_at"] = [client_character.global_position.x, client_character.global_position.y,
				client_character.global_position.z]
		return


func _finish(report_path: String, problem: String) -> void:
	_report["problem"] = problem
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report))
		file.close()
	Net.stop()
	quit()
