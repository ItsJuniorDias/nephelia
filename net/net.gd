class_name Net
extends Object
## Sessão do multiplayer: se este aparelho joga sozinho, hospeda ou entrou na partida de outro, a
## conexão aberta (`transport`) e quem está na sala (`roster`).
##
## Classe só de membros estáticos (como `Settings`): sobrevive à troca de cena do menu para a
## arena, e os testes (`-s`) enxergam o nome. Quem cuida da partida em si é o `NetGame` (criado
## pela arena: `NetHost` no anfitrião, `NetClient` nos outros).

enum Mode { OFFLINE, HOST, CLIENT }

## Jogadores humanos por partida (o anfitrião conta). Bots completam até `MIN_CHARACTERS`.
## Pedido do usuário (2026-09-24): até 4 pessoas.
const MAX_PLAYERS: int = 4
const MIN_CHARACTERS: int = 4
## Porta em que o anfitrião responde a quem procura salas no Wi-Fi (LanBeacon / LanScanner).
const DISCOVERY_PORT: int = 24682

static var mode: Mode = Mode.OFFLINE
static var transport: NetTransport
## Quem está na sala: {id do aparelho: nome}. O anfitrião é `NetTransport.HOST_ID`.
static var roster: Dictionary[int, String] = {}
## Por que a última partida em rede acabou ("" = saiu por vontade própria). O menu mostra.
static var last_error: String = ""
## Anfitrião: responde a quem procura salas no Wi-Fi (null = ninguém acha esta sala sozinho).
static var beacon: LanBeacon
## Número sorteado da sala (quem procura junta as respostas do mesmo anfitrião por ele).
static var room_id: int = 0
## Anfitrião: a partida já está rolando (quem acha a sala vê "playing" e entra no meio).
static var match_running: bool = false
## Servidor dedicado (partida online): hospeda sem jogador daqui (ver DedicatedServer).
static var dedicated: bool = false


static func is_online() -> bool:
	return mode != Mode.OFFLINE and transport != null


static func is_host() -> bool:
	return mode == Mode.HOST and transport != null


static func is_client() -> bool:
	return mode == Mode.CLIENT and transport != null


## Id deste aparelho na partida (0 = offline).
static func local_id() -> int:
	return transport.local_id if transport != null else 0


## Abre uma sala no Wi-Fi local (este aparelho vira o anfitrião). Quem procura salas acha esta
## pela porta `discovery_port` (0 = não responde; testes).
static func host_lan(player_name: String, port: int = NetMessage.PORT,
		discovery_port: int = DISCOVERY_PORT) -> Error:
	stop()
	var enet := EnetTransport.new()
	var err: Error = enet.host(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	transport = enet
	mode = Mode.HOST
	roster = {NetTransport.HOST_ID: player_name}
	last_error = ""
	room_id = randi() & 0x7fffffff
	match_running = false
	if discovery_port > 0:
		beacon = LanBeacon.new()
		# Porta ocupada (outra sala neste aparelho): a sala funciona, só não é achada sozinha.
		if beacon.start(discovery_port, port) != OK:
			beacon = null
	return OK


## Servidor dedicado: hospeda a partida sem jogador neste aparelho (todas as vagas são de fora) e
## sem responder a quem procura salas no Wi-Fi. `websocket` = conexão por WebSocket (servidor no
## Render, atrás do matchmaker), escutando em `bind_address`; senão ENet (UDP).
static func host_dedicated(port: int, websocket: bool = false, bind_address: String = "*") -> Error:
	stop()
	var server: NetTransport
	if websocket:
		var socket := WebSocketTransport.new()
		socket.bind_address = bind_address
		server = socket
	else:
		server = EnetTransport.new()
	var err: Error = server.host(port, MAX_PLAYERS)
	if err != OK:
		return err
	transport = server
	mode = Mode.HOST
	dedicated = true
	roster = {}
	last_error = ""
	room_id = randi() & 0x7fffffff
	match_running = true
	return OK


## Humanos que já ocupam vaga na partida hospedada aqui (o anfitrião conta, se não é dedicado).
static func host_seats() -> int:
	return 0 if dedicated else 1


## Entra numa partida online (servidor dedicado) no endereço que o matchmaker indicou: uma URL
## "wss://..." (servidor no Render, por WebSocket) ou endereço e porta (ENet).
static func join_online(address: String, port: int) -> Error:
	if not (address.begins_with("ws://") or address.begins_with("wss://")):
		return join_lan(address, port)
	stop()
	var socket := WebSocketTransport.new()
	var err: Error = socket.join(address, port)
	if err != OK:
		return err
	transport = socket
	mode = Mode.CLIENT
	roster = {}
	last_error = ""
	return OK


## Entra na sala de outro aparelho pelo endereço dele (ex.: "192.168.0.12").
static func join_lan(address: String, port: int = NetMessage.PORT) -> Error:
	stop()
	var enet := EnetTransport.new()
	var err: Error = enet.join(address, port)
	if err != OK:
		return err
	transport = enet
	mode = Mode.CLIENT
	roster = {}
	last_error = ""
	return OK


## Lê o que chegou pela conexão e responde a quem procura salas (chamar a cada passo).
static func poll() -> void:
	if transport != null:
		transport.poll()
	if beacon != null:
		beacon.poll()


## Fecha a conexão e volta a jogar sozinho. `reason` fica em `last_error` para o menu mostrar.
static func stop(reason: String = "") -> void:
	if beacon != null:
		beacon.stop()
		beacon = null
	match_running = false
	dedicated = false
	if transport != null:
		if transport.is_open():
			transport.send(0, NetMessage.pack(NetMessage.Type.LEAVE), true)
		var old: NetTransport = transport
		transport = null
		old.close()
	mode = Mode.OFFLINE
	roster = {}
	last_error = reason


## Anfitrião: confere o HELLO de quem quer entrar. Devolve o motivo da recusa ("" = pode entrar).
static func check_hello(data: Array, players_now: int) -> String:
	if data.size() < 2 or not data[0] is int or not data[1] is String:
		return "invalid request"
	if data[0] != NetMessage.VERSION:
		return "different game version"
	if players_now >= MAX_PLAYERS:
		return "the match is full"
	return ""


## Endereços deste aparelho na rede local (para o anfitrião dizer aos amigos onde entrar).
static func local_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_private_172(address):
			found.append(address)
	return found


static func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var parts: PackedStringArray = address.split(".")
	return parts.size() == 4 and parts[1].to_int() >= 16 and parts[1].to_int() <= 31
