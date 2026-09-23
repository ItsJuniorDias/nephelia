class_name NetTransport
extends RefCounted
## "Estrada" dos dados do multiplayer: liga os aparelhos e leva pacotes de bytes entre eles.
##
## O jogo só fala com esta classe. Cada tipo de conexão é uma filha: `EnetTransport` (Wi-Fi local,
## e o Mac nos testes) e, depois, o Game Center. Quem hospeda é sempre o id `HOST_ID`; os outros
## só conversam com ele (o anfitrião é o servidor da partida).
##
## Também finge uma rede ruim (atraso, variação e perda), para testar sem precisar do celular.

signal peer_joined(peer: int)
signal peer_left(peer: int)
## Chegou um pacote de `peer` (já com o atraso simulado, se houver).
signal packet_received(peer: int, bytes: PackedByteArray)
## Cliente: conectou ao anfitrião.
signal connected
## Cliente: não conseguiu conectar (ou a conexão caiu antes de completar).
signal connection_failed
## A conexão acabou (o anfitrião saiu, a rede caiu ou `close()`).
signal closed

const HOST_ID: int = 1

## Atraso simulado em cada pacote que CHEGA (ms). Ida e volta = o dobro (os dois lados atrasam).
var simulated_latency_ms: int = 0
## Variação sorteada em cima do atraso (ms).
var simulated_jitter_ms: int = 0
## Fração dos pacotes NÃO confiáveis que se perde (0 a 1). Os confiáveis só atrasam.
var simulated_loss: float = 0.0

## Id deste aparelho (anfitrião = HOST_ID; 0 = ainda sem conexão).
var local_id: int = 0
var is_host: bool = false

## Pacotes esperando o atraso simulado: [{"at": msec, "peer": int, "bytes": PackedByteArray}].
var _delayed: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Anfitrião: abre a partida para até `max_clients` outros aparelhos.
func host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


## Cliente: conecta ao anfitrião.
func join(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


## Manda `bytes` para `peer` (0 = todos). `reliable` = chega sempre e na ordem (eventos);
## senão pode se perder (fotos do estado, comandos: o próximo substitui).
func send(_peer: int, _bytes: PackedByteArray, _reliable: bool) -> void:
	pass


## Recebe o que chegou e entrega (chamar a cada passo de física).
func poll() -> void:
	_poll_raw()
	if _delayed.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	while not _delayed.is_empty() and _delayed[0]["at"] <= now:
		var item: Dictionary = _delayed.pop_front()
		packet_received.emit(item["peer"], item["bytes"])


func close() -> void:
	_delayed.clear()


## Tem conexão aberta (anfitrião escutando ou cliente conectado).
func is_open() -> bool:
	return false


## Ids dos outros aparelhos conectados.
func get_peers() -> PackedInt32Array:
	return PackedInt32Array()


## Tempo de ida e volta até `peer` (ms), se a conexão souber medir; -1 = não sabe.
func get_round_trip_ms(_peer: int) -> int:
	return -1


# Cada filha lê a própria conexão aqui e chama `_receive` para cada pacote.
func _poll_raw() -> void:
	pass


# Entrega um pacote que chegou, passando pelo atraso e pela perda simulados.
func _receive(peer: int, bytes: PackedByteArray, reliable: bool) -> void:
	if not reliable and simulated_loss > 0.0 and _rng.randf() < simulated_loss:
		return
	if simulated_latency_ms <= 0 and simulated_jitter_ms <= 0 and _delayed.is_empty():
		packet_received.emit(peer, bytes)
		return
	var delay: int = simulated_latency_ms + _rng.randi_range(0, maxi(simulated_jitter_ms, 0))
	var at: int = Time.get_ticks_msec() + delay
	# Confiáveis chegam na ordem: nunca antes do último da fila (a variação não os embaralha).
	if reliable and not _delayed.is_empty():
		at = maxi(at, _delayed[_delayed.size() - 1]["at"])
	var item: Dictionary = {"at": at, "peer": peer, "bytes": bytes}
	var index: int = _delayed.size()
	while index > 0 and _delayed[index - 1]["at"] > at:
		index -= 1
	_delayed.insert(index, item)
