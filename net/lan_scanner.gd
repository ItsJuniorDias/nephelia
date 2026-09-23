class_name LanScanner
extends RefCounted
## Procura salas do Nephelia no mesmo Wi-Fi, sem digitar endereço: pergunta "tem sala aí?" a cada
## endereço da rede de casa (x.x.x.1 a x.x.x.254) e junta as respostas do LanBeacon.
##
## Por que não um "grito para todos" (broadcast): no iPhone, mandar ou receber broadcast exige uma
## permissão especial da Apple (multicast). Perguntar endereço por endereço só precisa da
## permissão comum de rede local (NSLocalNetworkUsageDescription), que o jogo já tem. São 254
## pacotes de 5 bytes a cada 1,5 s: nada para a rede.

signal rooms_changed

const SCAN_INTERVAL_MS: int = 1500
## Sala que parou de responder some da lista depois disto.
const FORGET_AFTER_MS: int = 4500
## Redes (x.x.x.*) varridas no máximo (o aparelho pode ter mais de uma interface).
const MAX_SUBNETS: int = 3

var discovery_port: int = Net.DISCOVERY_PORT
## Também pergunta aqui: o próprio aparelho (duas janelas no Mac, testes).
var extra_addresses: PackedStringArray = PackedStringArray(["127.0.0.1"])
## Salas achadas, por número da sala: {"room", "address", "port", "host", "players",
## "max_players", "in_match", "seen"}.
var rooms: Dictionary[int, Dictionary] = {}

var _udp := PacketPeerUDP.new()
var _next_scan: int = 0


func start() -> Error:
	stop()
	_next_scan = 0
	return _udp.bind(0)


func is_running() -> bool:
	return _udp.is_bound()


func stop() -> void:
	_udp.close()
	if not rooms.is_empty():
		rooms.clear()
		rooms_changed.emit()


## Pergunta de novo quando for hora, lê as respostas e esquece quem sumiu (chamar a cada quadro).
func poll() -> void:
	if not _udp.is_bound():
		return
	var now: int = Time.get_ticks_msec()
	if now >= _next_scan:
		_next_scan = now + SCAN_INTERVAL_MS
		_ask_everyone()
	var changed: bool = false
	while _udp.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _udp.get_packet()
		var address: String = _udp.get_packet_ip()
		changed = _read_answer(bytes, address, now) or changed
	for room: int in rooms.keys():
		if now - int(rooms[room]["seen"]) > FORGET_AFTER_MS:
			rooms.erase(room)
			changed = true
	if changed:
		rooms_changed.emit()


## Salas achadas, em ordem de nome do anfitrião.
func room_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for room: int in rooms:
		list.append(rooms[room])
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["host"]) < str(b["host"]))
	return list


func _ask_everyone() -> void:
	var question: PackedByteArray = LanBeacon.QUESTION.to_ascii_buffer()
	for address: String in _targets():
		_udp.set_dest_address(address, discovery_port)
		_udp.put_packet(question)


# Os endereços extras e todos os da(s) rede(s) de casa deste aparelho.
func _targets() -> PackedStringArray:
	var targets := PackedStringArray(extra_addresses)
	var subnets: PackedStringArray = []
	for own: String in Net.local_addresses():
		var parts: PackedStringArray = own.split(".")
		if parts.size() != 4:
			continue
		var subnet: String = "%s.%s.%s." % [parts[0], parts[1], parts[2]]
		if subnet in subnets or subnets.size() >= MAX_SUBNETS:
			continue
		subnets.append(subnet)
		for last: int in range(1, 255):
			var address: String = subnet + str(last)
			if address != own:
				targets.append(address)
		# O próprio endereço também (o anfitrião pode ser este aparelho, outra janela).
		targets.append(own)
	return targets


# Resposta de um anfitrião: [ANSWER, versão, sala, nome, jogadores, máximo, porta, em partida].
func _read_answer(bytes: PackedByteArray, address: String, now: int) -> bool:
	if bytes.size() < 8 or bytes.size() > 512 or address.is_empty():
		return false
	var data: Variant = bytes_to_var(bytes)
	if not data is Array:
		return false
	var answer: Array = data
	if answer.size() != 8 or answer[0] != LanBeacon.ANSWER or not (answer[1] is int and answer[2] is int
			and answer[3] is String and answer[4] is int and answer[5] is int and answer[6] is int
			and answer[7] is bool):
		return false
	# Outra versão do jogo não conversa com esta: nem aparece.
	if answer[1] != NetMessage.VERSION:
		return false
	var room: int = answer[2]
	var known: bool = rooms.has(room)
	var before: Dictionary = rooms.get(room, {})
	var info: Dictionary = {"room": room, "address": before.get("address", address), "port": answer[6],
			"host": Settings.clean_name(answer[3]), "players": answer[4], "max_players": answer[5],
			"in_match": answer[7], "seen": now}
	# O mesmo aparelho responde por mais de um endereço (rede e 127.0.0.1): prefere o da rede.
	if known and str(before["address"]) == "127.0.0.1" and address != "127.0.0.1":
		info["address"] = address
	rooms[room] = info
	return not known or before["players"] != info["players"] or before["in_match"] != info["in_match"] \
			or before["host"] != info["host"]
