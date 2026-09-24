class_name NetLobby
extends Node
## Sala do multiplayer, antes da partida: quem entra, a lista de jogadores e o "começar".
## Sem tela (a tela é `ui/lobby/`), para os testes usarem igual.
##
## Anfitrião: aceita (ou recusa) quem manda HELLO, mantém `Net.roster` e manda a lista a todos.
## A partida começa quando o anfitrião aperta START (`start_match()`; pedido do usuário,
## 2026-09-24: com até 4 pessoas, a sala espera todo mundo entrar). Quem chega depois entra no meio
## da partida (NetHost), no lugar de um bot. Com `auto_start_delay` >= 0 a sala começa sozinha
## esse tanto de segundos depois que alguém entra (era o jeito até 2026-09-24; hoje só os testes
## usam). Cliente: manda HELLO ao conectar, recebe a lista e espera o START. Os pacotes são lidos
## aqui (`_process`) enquanto a sala está aberta.

signal roster_changed
## Todos vão para a arena agora (quem está com a sala aberta troca de cena).
signal match_starting
## Cliente: entrou na sala do anfitrião.
signal joined
## A sala acabou: não conectou, foi recusado ou o anfitrião fechou. `reason` em inglês (tela).
signal failed(reason: String)
## Anfitrião: segundos até a partida começar sozinha (-1 = parou: todo mundo saiu).
signal countdown_changed(seconds_left: int)

## Anfitrião: a partida começa sozinha este tanto de segundos depois que o primeiro amigo entra
## (-1 = só pelo botão START).
var auto_start_delay: float = -1.0

var _hello_sent: bool = false
var _started: bool = false
## Tempo que falta para começar (-1 = sem contagem).
var _countdown: float = -1.0
var _shown_seconds: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var transport: NetTransport = Net.transport
	if transport == null:
		return
	transport.packet_received.connect(_on_packet)
	transport.peer_left.connect(_on_peer_left)
	transport.connected.connect(_on_connected)
	transport.connection_failed.connect(_on_connection_failed)
	transport.closed.connect(_on_closed)
	# Conectou antes de a sala abrir: já se apresenta.
	if Net.is_client() and transport.is_open():
		_on_connected()


func _process(delta: float) -> void:
	Net.poll()
	if Net.is_host() and not _started and auto_start_delay >= 0.0:
		_count_down(delta)


## Anfitrião: começa a partida para todos da sala agora.
func start_match() -> void:
	if not Net.is_host() or _started:
		return
	_started = true
	Net.transport.send(0, NetMessage.pack(NetMessage.Type.START, []), true)
	match_starting.emit()


## Segundos (arredondados para cima) até começar; -1 = sem contagem.
func seconds_to_start() -> int:
	return ceili(_countdown) if _countdown >= 0.0 else -1


# Alguém entrou: conta e começa. Todo mundo saiu antes do fim: para a contagem.
func _count_down(delta: float) -> void:
	if Net.roster.size() < 2:
		if _countdown >= 0.0:
			_countdown = -1.0
			_shown_seconds = -1
			countdown_changed.emit(-1)
		return
	if _countdown < 0.0:
		_countdown = auto_start_delay
	else:
		_countdown -= delta
	var seconds: int = maxi(ceili(_countdown), 0)
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		countdown_changed.emit(seconds)
	if _countdown <= 0.0:
		start_match()


## Nomes na sala, o anfitrião primeiro.
func player_names() -> PackedStringArray:
	var names := PackedStringArray()
	var peers: Array[int] = Net.roster.keys()
	peers.sort()
	for peer: int in peers:
		names.append(Net.roster[peer])
	return names


func _on_connected() -> void:
	if _hello_sent:
		return
	_hello_sent = true
	Net.transport.send(NetTransport.HOST_ID,
			NetMessage.pack(NetMessage.Type.HELLO, [NetMessage.VERSION, Settings.player_name]), true)


func _on_packet(peer: int, bytes: PackedByteArray) -> void:
	var data: Array = NetMessage.unpack(bytes)
	match NetMessage.type_of(bytes):
		NetMessage.Type.HELLO:
			if Net.is_host():
				_on_hello(peer, data)
		NetMessage.Type.LEAVE:
			if Net.is_host():
				_on_peer_left(peer)
		NetMessage.Type.ROSTER:
			if Net.is_client():
				_on_roster(data)
		NetMessage.Type.START:
			if Net.is_client():
				match_starting.emit()
		NetMessage.Type.REJECT:
			if Net.is_client():
				var reason: String = "The host refused: %s" % (str(data[0]) if not data.is_empty() else "?")
				Net.stop(reason)
				failed.emit(reason)


func _on_hello(peer: int, data: Array) -> void:
	var problem: String = Net.check_hello(data, Net.roster.size())
	if not problem.is_empty():
		Net.transport.send(peer, NetMessage.pack(NetMessage.Type.REJECT, [problem]), true)
		return
	Net.roster[peer] = Settings.clean_name(data[1])
	_send_roster()


func _on_peer_left(peer: int) -> void:
	if Net.is_host() and Net.roster.has(peer):
		Net.roster.erase(peer)
		_send_roster()


func _send_roster() -> void:
	var rows: Array = []
	for peer: int in Net.roster:
		rows.append([peer, Net.roster[peer]])
	Net.transport.send(0, NetMessage.pack(NetMessage.Type.ROSTER, [rows]), true)
	roster_changed.emit()


func _on_roster(data: Array) -> void:
	if data.size() != 1 or not data[0] is Array:
		return
	var was_in: bool = Net.roster.has(Net.local_id())
	Net.roster.clear()
	for row: Variant in data[0]:
		if row is Array and (row as Array).size() == 2 and row[0] is int and row[1] is String:
			Net.roster[row[0]] = Settings.clean_name(row[1])
	roster_changed.emit()
	if not was_in and Net.roster.has(Net.local_id()):
		joined.emit()


func _on_connection_failed() -> void:
	var reason: String = "Could not reach the host."
	Net.stop(reason)
	failed.emit(reason)


func _on_closed() -> void:
	if Net.is_client():
		var reason: String = "The host closed the room."
		Net.stop(reason)
		failed.emit(reason)
