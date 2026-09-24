class_name WebSocketTransport
extends NetTransport
## Conexão por WebSocket (TCP), para a partida online hospedada no Render: lá só entra HTTP(S) por
## uma porta, então o jogo conecta em `wss://<serviço>.onrender.com/play/<partida>` e o
## matchmaker (Node) repassa a conexão para o servidor da partida na mesma máquina.
## O Wi-Fi local continua no `EnetTransport` (UDP).
##
## Como o `EnetTransport`, usa o `WebSocketMultiplayerPeer` só como cano de pacotes (sem RPC). No
## TCP tudo chega, e na ordem: "não confiável" vira confiável (um pacote perdido segura os
## seguintes; é o preço de passar pelo Render). O algoritmo de Nagle fica desligado (pacote
## pequeno sai na hora, sem esperar juntar).

var _peer: WebSocketMultiplayerPeer
var _was_connected: bool = false
var _peers := PackedInt32Array()
var _max_clients: int = 0
## Anfitrião: endereço em que escuta ("*" = todos; "127.0.0.1" = só quem está na máquina, atrás
## do matchmaker).
var bind_address: String = "*"


func host(port: int, max_clients: int) -> Error:
	close()
	_peer = WebSocketMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, bind_address)
	if err != OK:
		_peer = null
		return err
	_peer.refuse_new_connections = false
	_max_clients = max_clients
	_connect_signals()
	is_host = true
	local_id = HOST_ID
	return OK


## `address` pode ser a URL inteira ("wss://nephelia.onrender.com/play/m1") ou só o endereço
## (vira "ws://<endereço>:<porta>").
func join(address: String, port: int) -> Error:
	close()
	var url: String = address if address.begins_with("ws://") or address.begins_with("wss://") \
			else "ws://%s:%d" % [address, port]
	_peer = WebSocketMultiplayerPeer.new()
	var err: Error = _peer.create_client(url)
	if err != OK:
		_peer = null
		return err
	_connect_signals()
	is_host = false
	local_id = 0
	return OK


func send(peer: int, bytes: PackedByteArray, _reliable: bool) -> void:
	if not is_open():
		return
	# Só para conexões abertas: quem está saindo (conexão fechando) não recebe mais nada (mandar
	# para ela enche o log de erros do Godot). `peer` 0 = todos (no cliente, "todos" é o anfitrião).
	if peer != 0:
		_send_to(peer, bytes)
	elif is_host:
		for target: int in _peers:
			_send_to(target, bytes)
	else:
		_send_to(HOST_ID, bytes)


func _send_to(peer: int, bytes: PackedByteArray) -> void:
	if not _peers.has(peer):
		return
	var socket: WebSocketPeer = _peer.get_peer(peer)
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.set_target_peer(peer)
	_peer.put_packet(bytes)


func close() -> void:
	super.close()
	var was_open: bool = _peer != null and (_was_connected or is_host)
	if _peer != null:
		# Entrega o que ainda está na fila (ex.: "saí da partida") antes de fechar.
		_peer.poll()
		_peer.close()
		_peer = null
	_was_connected = false
	_peers.clear()
	is_host = false
	local_id = 0
	if was_open:
		closed.emit()


func is_open() -> bool:
	return _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_peers() -> PackedInt32Array:
	return _peers.duplicate()


func _poll_raw() -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from: int = _peer.get_packet_peer()
		var bytes: PackedByteArray = _peer.get_packet()
		_receive(from, bytes, true)
	# Cliente que ficou sem conexão: o servidor saiu, a rede caiu ou nunca conectou.
	if _peer != null and not is_host \
			and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		var had_connection: bool = _was_connected
		_peer = null
		_was_connected = false
		_peers.clear()
		local_id = 0
		if had_connection:
			closed.emit()
		else:
			connection_failed.emit()


func _connect_signals() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(peer: int) -> void:
	var socket: WebSocketPeer = _peer.get_peer(peer)
	if socket != null:
		socket.set_no_delay(true)
	if is_host:
		# Sala cheia: fecha quem passou do limite (o HELLO também recusaria).
		if _max_clients > 0 and _peers.size() >= _max_clients:
			_peer.disconnect_peer(peer)
			return
		if not _peers.has(peer):
			_peers.append(peer)
		peer_joined.emit(peer)
	elif peer == HOST_ID:
		if not _peers.has(peer):
			_peers.append(peer)
		local_id = _peer.get_unique_id()
		_was_connected = true
		connected.emit()


func _on_peer_disconnected(peer: int) -> void:
	var index: int = _peers.find(peer)
	if index >= 0:
		_peers.remove_at(index)
	# No cliente, a saída do servidor é tratada no _poll_raw (a conexão toda acaba).
	if is_host:
		peer_left.emit(peer)
