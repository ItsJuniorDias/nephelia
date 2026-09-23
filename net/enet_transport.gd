class_name EnetTransport
extends NetTransport
## Conexão pela rede local (Wi-Fi) ou pela internet com endereço direto, usando o ENet do Godot.
## Serve também para testar no Mac (duas janelas, endereço 127.0.0.1).
##
## O `ENetMultiplayerPeer` é usado sozinho, só como cano de pacotes (sem RPC nem
## `multiplayer.multiplayer_peer`): o protocolo do jogo é nosso (`NetMessage`), e assim o Game
## Center pode entrar no lugar sem mudar nada no jogo. Mensagens confiáveis e não confiáveis vão
## em canais separados do ENet (o ENetMultiplayerPeer faz isso sozinho no canal 0).
##
## O "acelerador" do ENet fica desligado: quando ele acha que a rede está congestionada (o que
## acontece logo que o cliente termina de carregar a arena), joga fora pacotes não confiáveis de
## propósito, e sumiam fotos do estado por quase 1 s (personagens pulando 3,5 m nos testes).
## Nossos pacotes são pequenos; quem decide o que pode se perder somos nós.

var _peer: ENetMultiplayerPeer
var _was_connected: bool = false
var _peers := PackedInt32Array()


func host(port: int, max_clients: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, max_clients)
	if err != OK:
		_peer = null
		return err
	_connect_signals()
	is_host = true
	local_id = HOST_ID
	return OK


func join(address: String, port: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	_connect_signals()
	is_host = false
	local_id = _peer.get_unique_id()
	return OK


func send(peer: int, bytes: PackedByteArray, reliable: bool) -> void:
	if not is_open():
		return
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable \
			else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
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


func get_round_trip_ms(peer: int) -> int:
	if _peer == null:
		return -1
	var connection: ENetPacketPeer = _peer.get_peer(peer)
	if connection == null:
		return -1
	return int(connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func _poll_raw() -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from: int = _peer.get_packet_peer()
		var mode: MultiplayerPeer.TransferMode = _peer.get_packet_mode()
		var bytes: PackedByteArray = _peer.get_packet()
		_receive(from, bytes, mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	# Cliente que ficou sem conexão: o anfitrião saiu, a rede caiu ou nunca conectou.
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
	if not _peers.has(peer):
		_peers.append(peer)
	var connection: ENetPacketPeer = _peer.get_peer(peer)
	if connection != null:
		# Nunca desacelera (desaceleração 0): pacote não confiável só se perde se a rede perder.
		connection.throttle_configure(1000, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)
	if is_host:
		peer_joined.emit(peer)
	elif peer == HOST_ID:
		_was_connected = true
		connected.emit()


func _on_peer_disconnected(peer: int) -> void:
	var index: int = _peers.find(peer)
	if index >= 0:
		_peers.remove_at(index)
	# No cliente, a saída do anfitrião é tratada no _poll_raw (a conexão toda acaba).
	if is_host:
		peer_left.emit(peer)
