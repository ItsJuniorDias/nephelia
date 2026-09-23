class_name NetMessage
extends RefCounted
## Protocolo do multiplayer: os tipos de mensagem e como cada uma vira bytes.
##
## Todo pacote começa com um byte do tipo. As mensagens frequentes (comandos, 60 por segundo, e a
## "foto" do estado, 30 por segundo) são binárias e compactas (ver `pack_input` e `NetSnapshot`).
## Os eventos (morte, item, placar...) são raros: vão como uma lista do Godot (`var_to_bytes`,
## sem objetos, então um pacote malicioso não cria nada no aparelho).

## Sobe quando o protocolo muda: aparelhos com versões diferentes não jogam juntos.
const VERSION: int = 1
## Porta padrão do Wi-Fi local.
const PORT: int = 24680
## Comandos repetidos em cada pacote de entrada (se um pacote se perde, o próximo cobre).
const INPUT_REDUNDANCY: int = 3
## Nomes das armas pela rede (índice = número mandado).
const WEAPON_IDS: Array[StringName] = [&"revolver", &"repeater", &"shotgun"]

enum Type {
	## cliente -> anfitrião: [versão, nome]
	HELLO = 1,
	## anfitrião -> cliente: [motivo]; a conexão é fechada em seguida
	REJECT,
	## anfitrião -> todos, no lobby: [[id do aparelho, nome], ...]
	ROSTER,
	## anfitrião -> todos: começar a partida: [ajustes]
	START,
	## cliente -> anfitrião: arena carregada, pode mandar o mundo
	READY,
	## anfitrião -> cliente: [seu personagem, [personagens], estado da partida]
	WORLD,
	## anfitrião -> todos: [personagem]
	CHARACTER_ADDED,
	## anfitrião -> todos: [id]
	CHARACTER_REMOVED,
	## cliente -> anfitrião (não confiável): comandos (binário)
	INPUT,
	## anfitrião -> cliente (não confiável): foto do estado (binário, NetSnapshot)
	SNAPSHOT,
	## anfitrião -> todos: um tiro resolvido (confiável: traz a confirmação do acerto)
	SHOT,
	## anfitrião -> todos: [vítima, matador, passo]
	DIED,
	## anfitrião -> todos: [id, transform, proteção, passo]
	RESPAWNED,
	## anfitrião -> todos: [índice do item, disponível, quem pegou]
	PICKUP,
	## anfitrião -> todos: [id, arma, motivo]
	WEAPON,
	## anfitrião -> todos: [[id, abates, mortes], ...]
	SCORE,
	## anfitrião -> todos: [estado, tempo restante, placar]
	MATCH,
	## qualquer um: saindo da partida
	LEAVE,
}


## Monta uma mensagem de evento: tipo + lista.
static func pack(type: Type, data: Array = []) -> PackedByteArray:
	var bytes := PackedByteArray([type])
	bytes.append_array(var_to_bytes(data))
	return bytes


## Tipo da mensagem (0 = pacote vazio).
static func type_of(bytes: PackedByteArray) -> int:
	return bytes[0] if bytes.size() > 0 else 0


## Lê o conteúdo de uma mensagem de evento ([] se estiver estragada).
static func unpack(bytes: PackedByteArray) -> Array:
	# Menor lista possível: 4 bytes do tipo + 4 do tamanho.
	if bytes.size() < 9:
		return []
	var value: Variant = bytes_to_var(bytes.slice(1))
	return value if value is Array else []


## Comandos do jogador (os últimos, do mais antigo ao mais novo) num pacote de entrada.
static func pack_input(commands: Array[CharacterCommand]) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(Type.INPUT)
	buffer.put_u8(commands.size())
	for command: CharacterCommand in commands:
		buffer.put_u32(command.tick)
		buffer.put_8(quantize_axis(command.move.x))
		buffer.put_8(quantize_axis(command.move.y))
		buffer.put_float(command.yaw)
		buffer.put_float(command.pitch)
		buffer.put_u8(_buttons_of(command))
		buffer.put_float(command.view_tick)
	return buffer.data_array


## Lê um pacote de entrada ([] se estiver estragado).
static func unpack_input(bytes: PackedByteArray) -> Array[CharacterCommand]:
	var commands: Array[CharacterCommand] = []
	if bytes.size() < 2 or bytes[0] != Type.INPUT:
		return commands
	var count: int = bytes[1]
	# 4 + 1 + 1 + 4 + 4 + 1 + 4 bytes por comando.
	if count > 16 or bytes.size() != 2 + count * 19:
		return commands
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(2)
	for i: int in count:
		var command := CharacterCommand.new()
		command.tick = buffer.get_u32()
		command.move = Vector2(buffer.get_8() / 127.0, buffer.get_8() / 127.0)
		command.yaw = buffer.get_float()
		command.pitch = buffer.get_float()
		var buttons: int = buffer.get_u8()
		command.jump = buttons & 1 != 0
		command.fire = buttons & 2 != 0
		command.reload = buttons & 4 != 0
		command.aim_assist = buttons & 8 != 0
		command.use_rail = buttons & 16 != 0
		command.view_tick = buffer.get_float()
		if not (is_finite(command.yaw) and is_finite(command.pitch) and is_finite(command.view_tick)):
			commands.clear()
			return commands
		commands.append(command)
	return commands


## Deixa o comando exatamente como o anfitrião vai recebê-lo (o cliente prevê com os mesmos
## números, senão a previsão erra um pouquinho a cada passo).
static func quantize(command: CharacterCommand) -> void:
	command.move = Vector2(quantize_axis(command.move.x) / 127.0, quantize_axis(command.move.y) / 127.0)
	var buffer := StreamPeerBuffer.new()
	buffer.put_float(command.yaw)
	buffer.put_float(command.pitch)
	buffer.seek(0)
	command.yaw = buffer.get_float()
	command.pitch = buffer.get_float()


static func quantize_axis(value: float) -> int:
	return clampi(roundi(value * 127.0), -127, 127)


static func weapon_index(id: StringName) -> int:
	return maxi(WEAPON_IDS.find(id), 0)


static func weapon_id(index: int) -> StringName:
	return WEAPON_IDS[index] if index >= 0 and index < WEAPON_IDS.size() else WEAPON_IDS[0]


static func _buttons_of(command: CharacterCommand) -> int:
	return int(command.jump) | int(command.fire) << 1 | int(command.reload) << 2 \
			| int(command.aim_assist) << 3 | int(command.use_rail) << 4
