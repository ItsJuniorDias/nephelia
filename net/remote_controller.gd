class_name RemoteController
extends CharacterController
## Anfitrião: controla o personagem de um jogador de outro aparelho com os comandos que chegam
## pela rede (o mesmo CharacterCommand do humano e do bot, então as regras são as mesmas).
##
## Os comandos vêm numerados. A cada passo de física usa o próximo da fila. Se ainda não chegou
## (atraso da rede), o personagem ESPERA parado (`is_waiting`) e o anfitrião alcança depois,
## usando dois comandos por passo (NetHost): assim ele chega exatamente onde o cliente previu.
## Adivinhar (repetir o último comando) ou jogar comandos fora dava correções de até 0,7 m.
## Se a espera passar de `MAX_WAIT_TICKS`, segue com o último movimento, sem atirar.
## `last_tick` vai de volta na foto do estado: o cliente sabe até onde a previsão foi conferida.

## Fila máxima (meio segundo): acima disso os comandos mais velhos saem.
const MAX_QUEUE: int = 30
## Quantos ficam quando a fila é cortada.
const KEEP_QUEUE: int = 2
## Espera parado no máximo este tanto de passos por um comando atrasado (200 ms).
const MAX_WAIT_TICKS: int = 12

## Aparelho de quem é este personagem.
var peer: int = 0
## Último comando processado (-1 = nenhum ainda).
var last_tick: int = -1
## Em que passo do anfitrião o jogador estava vendo os outros ao mandar o comando atual
## (compensação do atraso nos tiros).
var view_tick: float = 0.0
## Passos sem comando novo (a rede atrasou): cada um vira uma pequena correção no cliente.
var starved: int = 0
## Comandos jogados fora porque a fila passou do limite.
var dropped: int = 0

var _queue: Dictionary[int, CharacterCommand] = {}
var _last: CharacterCommand
var _waited: int = 0


## Guarda os comandos que chegaram (repetidos e velhos são ignorados).
func push(commands: Array[CharacterCommand]) -> void:
	for incoming: CharacterCommand in commands:
		if incoming.tick > last_tick and not _queue.has(incoming.tick):
			_queue[incoming.tick] = incoming
	if _queue.size() > MAX_QUEUE:
		var ticks: Array[int] = _queue.keys()
		ticks.sort()
		for i: int in ticks.size() - KEEP_QUEUE:
			_queue.erase(ticks[i])
			dropped += 1


## Comandos esperando na fila (testes).
func queued() -> int:
	return _queue.size()


func is_waiting() -> bool:
	if not _queue.is_empty() or _last == null:
		_waited = 0
		return false
	if _waited < MAX_WAIT_TICKS:
		_waited += 1
		starved += 1
		return true
	return false


func get_command(_delta: float) -> CharacterCommand:
	var next: CharacterCommand = _next_in_queue()
	if next != null:
		_queue.erase(next.tick)
		last_tick = next.tick
		view_tick = next.view_tick
		_last = next
		command.copy_from(next)
		return command
	# Esperou demais: continua andando e olhando como antes, mas sem ações novas.
	if _last != null:
		command.copy_from(_last)
	else:
		command.reset()
		command.yaw = character.yaw
		command.pitch = character.pitch
	command.fire = false
	command.reload = false
	return command


## Esquece a fila (o personagem morreu ou renasceu: comandos velhos não valem mais).
func clear() -> void:
	_queue.clear()
	_last = null
	_waited = 0


func _next_in_queue() -> CharacterCommand:
	if _queue.is_empty():
		return null
	if _queue.has(last_tick + 1):
		return _queue[last_tick + 1]
	# Algum se perdeu: pula para o mais antigo que chegou.
	var smallest: int = -1
	for tick: int in _queue:
		if smallest < 0 or tick < smallest:
			smallest = tick
	return _queue[smallest]
