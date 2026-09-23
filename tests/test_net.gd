extends SceneTree
## Testes do multiplayer: protocolo, conexão (ENet no próprio Mac) e, depois, a partida em rede.
##
## Rodar (no Terminal, na pasta do projeto):
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_net.gd
## Código de saída 0 = tudo passou. Esta pasta não deve ir no jogo exportado.

## Porta dos testes (diferente da do jogo, para não brigar com uma partida aberta no Mac).
const TEST_PORT: int = 24790
const ARENA := "res://levels/skyplaza/skyplaza.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_input_roundtrip()
	_test_snapshot_roundtrip()
	_test_malformed_packets()
	await _test_enet_connection()
	await _test_simulated_network()
	await _test_room_starts_by_itself()
	await _test_find_room_on_wifi()
	await _test_match_over_network()
	await _test_join_running_match()

	print("RESULT: ", "ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(test_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", test_name, "  ", detail)
	else:
		_failures += 1
		print("FAIL  ", test_name, "  ", detail)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


# Espera até `condition` ficar verdadeira (ou `timeout_ms`), chamando poll nos transportes.
func _wait_until(condition: Callable, transports: Array, timeout_ms: int = 3000) -> bool:
	var until: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < until:
		for transport: NetTransport in transports:
			transport.poll()
		if condition.call():
			return true
		await process_frame
	return false


func _test_input_roundtrip() -> void:
	var commands: Array[CharacterCommand] = []
	for i: int in 3:
		var command := CharacterCommand.new()
		command.tick = 1000 + i
		command.move = Vector2(0.33 * i, -0.7)
		command.yaw = 1.2345678 + i
		command.pitch = -0.4
		command.jump = i == 1
		command.fire = i == 2
		command.use_rail = true
		command.aim_assist = i != 1
		command.view_tick = 990.5 + i
		NetMessage.quantize(command)
		commands.append(command)
	var decoded: Array[CharacterCommand] = NetMessage.unpack_input(NetMessage.pack_input(commands))
	var same: bool = decoded.size() == 3
	for i: int in mini(decoded.size(), 3):
		var a: CharacterCommand = commands[i]
		var b: CharacterCommand = decoded[i]
		# Depois de `quantize`, o que chega é EXATAMENTE o que o cliente usou para prever.
		same = same and a.tick == b.tick and a.move == b.move and a.yaw == b.yaw and a.pitch == b.pitch \
				and a.jump == b.jump and a.fire == b.fire and a.use_rail == b.use_rail \
				and a.aim_assist == b.aim_assist and is_equal_approx(a.view_tick, b.view_tick)
	_check("N1 commands survive the trip exactly (after quantize)", same,
			"decodificados=%d" % decoded.size())


func _test_snapshot_roundtrip() -> void:
	var snapshot := NetSnapshot.new()
	snapshot.tick = 123456
	snapshot.time_left = 187.25
	snapshot.entries.append({"id": 3, "flags": NetSnapshot.ALIVE | NetSnapshot.ON_RAIL,
			"position": Vector3(12.5, -3.25, 40.125), "velocity": Vector3(1.5, -2.0, 7.25),
			"yaw": 2.5, "pitch": -0.3, "health": 67, "weapon": 2})
	snapshot.entries.append({"id": 9, "flags": 0, "position": Vector3.ZERO, "velocity": Vector3.ZERO,
			"yaw": -3.1, "pitch": 0.0, "health": 0, "weapon": 0})
	snapshot.ack = 7777
	snapshot.own_state = PackedFloat32Array([1.0, 2.0, 3.5, -4.0])
	snapshot.own_ammo = 5
	snapshot.own_reserve = -1
	snapshot.own_weapon = 1
	snapshot.own_reloading = true
	var bytes: PackedByteArray = snapshot.encode(snapshot.encode_entries())
	var back: NetSnapshot = NetSnapshot.decode(bytes)
	var ok: bool = back != null and back.tick == 123456 and back.time_left == 187.25 \
			and back.entries.size() == 2 and back.ack == 7777 and back.own_state == snapshot.own_state \
			and back.own_ammo == 5 and back.own_reserve == -1 and back.own_weapon == 1 and back.own_reloading
	if ok:
		var first: Dictionary = back.entries[0]
		ok = first["id"] == 3 and first["flags"] == NetSnapshot.ALIVE | NetSnapshot.ON_RAIL \
				and first["position"] == Vector3(12.5, -3.25, 40.125) \
				and (first["velocity"] as Vector3).is_equal_approx(Vector3(1.5, -2.0, 7.25)) \
				and absf(first["yaw"] - 2.5) < 0.01 and first["health"] == 67 and first["weapon"] == 2
	_check("N2 the state snapshot survives the trip", ok, "%d bytes" % bytes.size())


func _test_malformed_packets() -> void:
	var junk := PackedByteArray([NetMessage.Type.SNAPSHOT, 1, 2, 3])
	var cut: PackedByteArray = NetMessage.pack_input([CharacterCommand.new()] as Array[CharacterCommand]).slice(0, 10)
	var event: Array = NetMessage.unpack(PackedByteArray([NetMessage.Type.DIED, 255, 0, 3]))
	_check("N3 broken packets are ignored without crashing",
			NetSnapshot.decode(junk) == null and NetMessage.unpack_input(cut).is_empty() and event.is_empty())


func _test_enet_connection() -> void:
	var host := EnetTransport.new()
	var client := EnetTransport.new()
	var host_log: Array = []
	var client_log: Array = []
	host.peer_joined.connect(func(peer: int) -> void: host_log.append(["joined", peer]))
	host.peer_left.connect(func(peer: int) -> void: host_log.append(["left", peer]))
	host.packet_received.connect(func(peer: int, bytes: PackedByteArray) -> void:
		host_log.append(["packet", peer, NetMessage.type_of(bytes), NetMessage.unpack(bytes)]))
	client.connected.connect(func() -> void: client_log.append(["connected"]))
	client.closed.connect(func() -> void: client_log.append(["closed"]))
	client.packet_received.connect(func(peer: int, bytes: PackedByteArray) -> void:
		client_log.append(["packet", peer, NetMessage.type_of(bytes), NetMessage.unpack(bytes)]))

	var opened: bool = host.host(TEST_PORT, 5) == OK and client.join("127.0.0.1", TEST_PORT) == OK
	var linked: bool = await _wait_until(func() -> bool:
		return client_log.has(["connected"]) and host_log.size() > 0, [host, client])
	var client_id: int = client.local_id
	_check("N4 a client connects to the host on this Mac", opened and linked and host.is_open()
			and client.is_open() and host.get_peers() == PackedInt32Array([client_id]),
			"host=%s cliente=%s" % [host_log, client_log])

	client.send(NetTransport.HOST_ID, NetMessage.pack(NetMessage.Type.HELLO, [NetMessage.VERSION, "Tester"]), true)
	host.send(client_id, NetMessage.pack(NetMessage.Type.SCORE, [[1, 2, 3]]), false)
	var delivered: bool = await _wait_until(func() -> bool:
		return host_log.any(func(item: Array) -> bool: return item[0] == "packet") \
				and client_log.any(func(item: Array) -> bool: return item[0] == "packet"), [host, client])
	var hello: Array = host_log.filter(func(item: Array) -> bool: return item[0] == "packet")
	_check("N5 reliable and unreliable messages arrive both ways", delivered and not hello.is_empty()
			and hello[0][1] == client_id and hello[0][2] == NetMessage.Type.HELLO
			and hello[0][3] == [NetMessage.VERSION, "Tester"], "anfitrião recebeu %s" % [hello])

	# O anfitrião fecha: o cliente fica sabendo que a partida acabou.
	host.close()
	var noticed: bool = await _wait_until(func() -> bool: return client_log.has(["closed"]), [client], 6000)
	_check("N6 the client notices when the host leaves", noticed and not client.is_open(), "%s" % [client_log])
	client.close()


func _test_simulated_network() -> void:
	var host := EnetTransport.new()
	var client := EnetTransport.new()
	var arrivals: Dictionary = {}
	client.packet_received.connect(func(_peer: int, bytes: PackedByteArray) -> void:
		var data: Array = NetMessage.unpack(bytes)
		arrivals[data[0]] = Time.get_ticks_msec())
	host.host(TEST_PORT + 1, 5)
	client.join("127.0.0.1", TEST_PORT + 1)
	await _wait_until(func() -> bool: return client.is_open() and not host.get_peers().is_empty(), [host, client])
	var client_id: int = host.get_peers()[0] if not host.get_peers().is_empty() else 0

	client.simulated_latency_ms = 150
	var sent_at: int = Time.get_ticks_msec()
	host.send(client_id, NetMessage.pack(NetMessage.Type.SCORE, ["late"]), true)
	await _wait_until(func() -> bool: return arrivals.has("late"), [host, client])
	var delay: int = arrivals.get("late", sent_at + 99999) - sent_at
	_check("N7 simulated latency delays arrival", delay >= 140 and delay < 400, "atraso=%d ms" % delay)

	client.simulated_latency_ms = 0
	client.simulated_loss = 1.0
	host.send(client_id, NetMessage.pack(NetMessage.Type.SCORE, ["lost"]), false)
	host.send(client_id, NetMessage.pack(NetMessage.Type.SCORE, ["kept"]), true)
	await _wait_until(func() -> bool: return arrivals.has("kept"), [host, client])
	await _wait_until(func() -> bool: return false, [host, client], 150)
	_check("N8 simulated loss drops only unreliable packets", arrivals.has("kept") and not arrivals.has("lost"))
	client.close()
	host.close()


# A sala começa a partida sozinha: alguém entra, conta alguns segundos e manda todos para a arena.
func _test_room_starts_by_itself() -> void:
	var port: int = TEST_PORT + 3
	Net.host_lan("Tester", port)
	var room := NetLobby.new()
	room.auto_start_delay = 0.4
	var seen: Array[int] = []
	var starting: Array[bool] = [false]
	room.countdown_changed.connect(func(seconds: int) -> void: seen.append(seconds))
	room.match_starting.connect(func() -> void: starting[0] = true)
	root.add_child(room)
	await _physics(10)
	var waited_alone: bool = not starting[0] and seen.is_empty()
	var friend := EnetTransport.new()
	var got_start: Array[bool] = [false]
	friend.packet_received.connect(func(_peer: int, bytes: PackedByteArray) -> void:
		if NetMessage.type_of(bytes) == NetMessage.Type.START:
			got_start[0] = true)
	friend.connected.connect(func() -> void:
		friend.send(NetTransport.HOST_ID, NetMessage.pack(NetMessage.Type.HELLO, [NetMessage.VERSION, "Friend"]), true))
	friend.join("127.0.0.1", port)
	var started_at: int = Time.get_ticks_msec()
	await _wait_until(func() -> bool: return got_start[0], [friend], 4000)
	var took: int = Time.get_ticks_msec() - started_at
	_check("N17 the room starts the match by itself when a friend joins", waited_alone and starting[0]
			and got_start[0] and not seen.is_empty() and seen[0] == 1 and took >= 350,
			"contagem=%s em %d ms" % [seen, took])
	friend.close()
	room.queue_free()
	Net.stop()
	await _physics(2)


# Achar a sala sem digitar endereço: o LanScanner pergunta e o anfitrião (LanBeacon) responde.
func _test_find_room_on_wifi() -> void:
	var discovery: int = TEST_PORT + 50
	Net.host_lan("Finder", TEST_PORT + 5, discovery)
	var scanner := LanScanner.new()
	scanner.discovery_port = discovery
	scanner.start()
	var until: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and scanner.rooms.is_empty():
		Net.poll()
		scanner.poll()
		await process_frame
	var found: Array[Dictionary] = scanner.room_list()
	var room: Dictionary = found[0] if not found.is_empty() else {}
	_check("N19 a game on the Wi-Fi is found without typing an address", found.size() == 1
			and room.get("host") == "Finder" and room.get("port") == TEST_PORT + 5 and room.get("players") == 1
			and room.get("in_match") == false and Net.beacon != null, "salas=%s" % [found])
	# A sala some da lista quando o anfitrião fecha.
	Net.stop()
	until = Time.get_ticks_msec() + LanScanner.FORGET_AFTER_MS + 3000
	while Time.get_ticks_msec() < until and not scanner.rooms.is_empty():
		scanner.poll()
		await process_frame
	_check("N20 a closed game disappears from the list", scanner.rooms.is_empty())
	scanner.stop()


# ---------------------------------------------------------------- partida de verdade

# Um anfitrião roda em OUTRO processo do Godot (tests/net_host_runner.gd); este teste entra na
# sala dele como cliente, joga e confere o que chega.
func _test_match_over_network() -> void:
	var port: int = TEST_PORT + 2
	var report_path: String = ProjectSettings.globalize_path("user://net_host_report.json")
	DirAccess.remove_absolute(report_path)
	var pid: int = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "res://tests/net_host_runner.gd", "--",
			str(port), report_path, "70"])
	Settings.player_name = "Tester"

	# O outro Godot leva alguns segundos para abrir a sala: tenta de novo até entrar.
	var lobby: NetLobby = null
	var starting: Array[bool] = [false]
	var in_room: bool = false
	for attempt: int in 30:
		Net.join_lan("127.0.0.1", port)
		lobby = NetLobby.new()
		root.add_child(lobby)
		lobby.match_starting.connect(func() -> void: starting[0] = true)
		in_room = await _wait_frames_until(func() -> bool:
			return Net.transport == null or Net.roster.has(Net.local_id()), 4000) \
				and Net.transport != null and Net.roster.has(Net.local_id())
		if in_room:
			break
		lobby.queue_free()
		Net.stop()
		await _wait_frames_until(func() -> bool: return false, 500)
	_check("N9 a client joins the host's room (another Godot on this Mac)", in_room
			and Net.roster.size() == 2 and Net.roster.values().has("HostBot"), "sala=%s" % [Net.roster])
	if not in_room:
		OS.kill(pid)
		return
	await _wait_frames_until(func() -> bool: return starting[0], 10000)
	lobby.queue_free()

	var level: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var deathmatch := level.get_node("Deathmatch") as Deathmatch
	await physics_frame
	var client := level.find_child("NetClient", true, false) as NetClient
	var ready: bool = client != null and await _wait_frames_until(func() -> bool:
		return client.has_world and not deathmatch.waiting, 20000)
	await _physics(20)
	var puppets: Array[Character] = []
	var host_character: Character = null
	if client != null:
		for id: int in client.characters:
			var character: Character = client.character_of(id)
			if character != null and character.controller is PuppetController:
				puppets.append(character)
				if character.display_name == "HostBot":
					host_character = character
	var placed: bool = puppets.all(func(c: Character) -> bool:
		return c.visible and c.global_position.length() > 1.0 and (c.controller as PuppetController).has_samples())
	_check("N10 the client gets the world: host, 2 bots and itself", ready and puppets.size() == 3
			and host_character != null and placed and client.local.net_id > 0,
			"marionetes=%s" % [puppets.map(func(c: Character) -> String: return c.display_name)])
	if not ready:
		_leave_network(level, pid)
		return
	var tags_ok: bool = true
	var tag_texts: Array[String] = []
	for puppet: Character in puppets:
		var tag := puppet.get_node_or_null(^"NameTag") as NameTag
		tags_ok = tags_ok and tag != null and tag.text.begins_with("BOT") == (puppet.display_name != "HostBot")
		tag_texts.append(tag.text if tag != null else "-")
	_check("N16 real players and bots are marked above their heads", tags_ok
			and client.local.get_node_or_null(^"NameTag") == null, "etiquetas=%s" % [tag_texts])

	# O anfitrião anda em círculo: a marionete dele anda aqui, sem pulos.
	var start: Vector3 = host_character.global_position
	var biggest_step: float = 0.0
	var previous: Vector3 = start
	var steps_log: Array = []
	for i: int in 60:
		await physics_frame
		var step: float = previous.distance_to(host_character.global_position)
		if step > 0.3:
			steps_log.append([i, previous, host_character.global_position, client.render_tick, client.tick,
					host_character.is_alive])
		biggest_step = maxf(biggest_step, step)
		previous = host_character.global_position
	if not steps_log.is_empty():
		print("saltos da marionete: ", steps_log)
	var travelled: float = start.distance_to(host_character.global_position)
	_check("N11 the host's character moves smoothly on the client", travelled > 2.0 and biggest_step < 0.3,
			"andou=%.2f m, maior passo=%.3f m" % [travelled, biggest_step])

	await _test_network_shot(client)
	await _test_prediction(client, 0, "N13 walking is predicted and the host agrees")
	Net.transport.simulated_latency_ms = 90
	Net.transport.simulated_jitter_ms = 20
	await _test_prediction(client, 1, "N14 with 100 ms of lag the prediction still holds")
	Net.transport.simulated_latency_ms = 0
	Net.transport.simulated_jitter_ms = 0

	var report: Dictionary = await _leave_network(level, pid, report_path)
	_check("N15 when the client leaves, a bot takes its place on the host",
			report.get("client_left", false) and int(report.get("bots_after_leave", -1)) == 3
			and int(report.get("characters_with_client", -1)) == 4, "relatório=%s" % [report])


# Mira no bot parado que o anfitrião pôs 6 m à frente e atira: o anfitrião confirma o acerto.
func _test_network_shot(client: NetClient) -> void:
	var local: Character = client.local
	var target: Character = null
	var best: float = INF
	for id: int in client.characters:
		var character: Character = client.character_of(id)
		if character != null and character != local and character.display_name != "HostBot":
			var distance: float = character.global_position.distance_to(local.global_position)
			if distance < best:
				best = distance
				target = character
	# Espera a proteção de nascimento do alvo acabar.
	await _wait_frames_until(func() -> bool: return false, 2500)
	var confirmed: Array[ShotResult] = []
	var on_confirmed := func(result: ShotResult) -> void: confirmed.append(result)

	local.weapon.hit_confirmed.connect(on_confirmed)
	var health_before: float = target.health if target != null else 0.0
	if target != null:
		var to_chest: Vector3 = target.global_position + Vector3.UP * 1.2 - local.head.global_position
		local.apply_look(atan2(-to_chest.x, -to_chest.z), atan2(to_chest.y, Vector2(to_chest.x, to_chest.z).length()))
		Input.action_press(&"fire")
		await _physics(3)
		Input.action_release(&"fire")
		await _wait_frames_until(func() -> bool: return not confirmed.is_empty(), 3000)
		await _physics(10)
	local.weapon.hit_confirmed.disconnect(on_confirmed)

	_check("N12 shooting a bot: the host confirms the hit and its health drops", target != null
			and not confirmed.is_empty() and target.health < health_before,
			"alvo=%s em %s (eu em %s), vida %.0f -> %.0f" % [target.display_name if target else "?",
			target.global_position if target else Vector3.ZERO, local.global_position,
			health_before, target.health if target else 0.0])


# Anda de lado e para trás por 1,5 s: o personagem responde na hora (previsão) e o anfitrião
# chega ao mesmo lugar (poucas correções, erro final pequeno).
func _test_prediction(client: NetClient, variant: int, test_name: String) -> void:
	var local: Character = client.local
	var start: Vector3 = local.global_position
	var corrections_before: int = client.corrections
	var action: StringName = &"move_left" if variant == 0 else &"move_back"
	Input.action_press(action)
	await _physics(3)
	var moved_early: float = start.distance_to(local.global_position)
	await _physics(87)
	Input.action_release(action)
	# Espera o anfitrião confirmar os últimos comandos.
	await _physics(40)
	var travelled: float = start.distance_to(local.global_position)
	var new_corrections: int = client.corrections - corrections_before
	_check(test_name, moved_early > 0.02 and travelled > 3.0 and new_corrections <= 3
			and client.last_prediction_error >= 0.0 and client.last_prediction_error < 0.05,
			"andou %.2f m (%.3f m nos 3 primeiros passos), correções=%d, erro final=%.3f m %s" % [travelled,
			moved_early, new_corrections, client.last_prediction_error,
			client.correction_log.slice(maxi(client.correction_log.size() - new_corrections, 0))])


func _leave_network(level: Node, pid: int, report_path: String = "") -> Dictionary:
	Net.stop()
	level.queue_free()
	current_scene = null
	var report: Dictionary = {}
	if report_path.is_empty():
		OS.kill(pid)
		return report
	await _wait_frames_until(func() -> bool: return FileAccess.file_exists(report_path), 15000)
	await _wait_frames_until(func() -> bool: return false, 300)
	var text: String = FileAccess.get_file_as_string(report_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		report = parsed
	if OS.is_process_running(pid):
		OS.kill(pid)
	return report


# Espera até `condition` ficar verdadeira (ou `timeout_ms`), deixando o jogo rodar.
func _wait_frames_until(condition: Callable, timeout_ms: int) -> bool:
	var until: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await process_frame
	return condition.call()


# A partida já está rolando (o anfitrião começou sozinho): um amigo entra no meio e toma a vaga
# de um bot.
func _test_join_running_match() -> void:
	var port: int = TEST_PORT + 4
	var report_path: String = ProjectSettings.globalize_path("user://net_host_report_alone.json")
	DirAccess.remove_absolute(report_path)
	var pid: int = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "res://tests/net_host_runner.gd", "--",
			str(port), report_path, "45", "0", "alone"])
	Settings.player_name = "Latecomer"
	var starting: Array[bool] = [false]
	var lobby: NetLobby = null
	for attempt: int in 30:
		Net.join_lan("127.0.0.1", port)
		lobby = NetLobby.new()
		root.add_child(lobby)
		lobby.match_starting.connect(func() -> void: starting[0] = true)
		if await _wait_frames_until(func() -> bool: return starting[0] or Net.transport == null, 4000) \
				and starting[0]:
			break
		lobby.queue_free()
		Net.stop()
		await _wait_frames_until(func() -> bool: return false, 500)
	if lobby != null:
		lobby.queue_free()
	var in_match: bool = false
	var puppets: Array[String] = []
	var level: Node = null
	if starting[0]:
		level = (load(ARENA) as PackedScene).instantiate()
		root.add_child(level)
		current_scene = level
		await physics_frame
		var client := level.find_child("NetClient", true, false) as NetClient
		in_match = client != null and await _wait_frames_until(func() -> bool:
			return client.has_world and not (level.get_node("Deathmatch") as Deathmatch).waiting, 20000)
		await _physics(10)
		if client != null:
			for id: int in client.characters:
				var character: Character = client.character_of(id)
				if character != null and character != client.local:
					puppets.append(("BOT " if character.is_bot else "") + character.display_name)
	var report: Dictionary = await _leave_network(level if level != null else Node.new(), pid, report_path)
	_check("N18 a friend joins a match already running and takes a bot's place", in_match
			and puppets.size() == 3 and puppets.count("HostBot") == 1 and report.get("joined_mid_match", false)
			and int(report.get("characters_with_client", -1)) == 4, "vê=%s relatório=%s" % [puppets,
			{"joined_mid_match": report.get("joined_mid_match"), "with_client": report.get("characters_with_client"),
			"problem": report.get("problem")}])
