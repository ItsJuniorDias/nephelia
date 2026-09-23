class_name LanBeacon
extends RefCounted
## Anfitrião no Wi-Fi local: responde "tem uma sala aqui" a quem procura (LanScanner), para
## ninguém precisar digitar endereço. Fica ligado na sala e durante a partida (dá para entrar no
## meio). Criado e lido pela `Net` (`Net.host_lan` / `Net.poll`).

## Pergunta de quem procura (curta: vai para cada endereço da rede).
const QUESTION := "NEPH?"
## Primeira palavra da resposta.
const ANSWER := "NEPH!"

var _udp := PacketPeerUDP.new()
var _game_port: int = 0


## Começa a escutar perguntas em `discovery_port`; quem achar a sala entra em `game_port`.
func start(discovery_port: int, game_port: int) -> Error:
	_game_port = game_port
	return _udp.bind(discovery_port)


func stop() -> void:
	_udp.close()


## Responde as perguntas que chegaram (chamar a cada quadro).
func poll() -> void:
	if not _udp.is_bound():
		return
	while _udp.get_available_packet_count() > 0:
		var question: PackedByteArray = _udp.get_packet()
		var address: String = _udp.get_packet_ip()
		var port: int = _udp.get_packet_port()
		if question.size() > 16 or question.get_string_from_ascii() != QUESTION or address.is_empty():
			continue
		var host_name: String = Net.roster.get(NetTransport.HOST_ID, "Player")
		var answer: PackedByteArray = var_to_bytes([ANSWER, NetMessage.VERSION, Net.room_id, host_name,
				Net.roster.size(), Net.MAX_PLAYERS, _game_port, Net.match_running])
		_udp.set_dest_address(address, port)
		_udp.put_packet(answer)
