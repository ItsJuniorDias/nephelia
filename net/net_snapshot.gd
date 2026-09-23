class_name NetSnapshot
extends RefCounted
## "Foto" do estado da partida que o anfitrião manda 30 vezes por segundo a cada cliente.
##
## Parte comum (todos recebem igual): o passo do anfitrião, o relógio e, por personagem, onde
## está, para onde olha, a velocidade, a vida e a arma. Parte de cada cliente: até qual comando
## dele o anfitrião já processou (`ack`) e o estado completo do movimento do personagem dele, para
## o cliente conferir a própria previsão (`Character.get_move_state`).

const ALIVE: int = 1
const ON_RAIL: int = 2
const RAIL_PULLING: int = 4
const AIRBORNE: int = 8
const PROTECTED: int = 16
const RELOADING: int = 32
## Bytes de cada personagem na parte comum.
const ENTRY_SIZE: int = 26
const MAX_OWN_STATE: int = 32

## Passo de física do anfitrião em que a foto foi tirada.
var tick: int = 0
## Segundos que faltam na partida.
var time_left: float = 0.0
## Personagens: {"id", "flags", "position", "velocity", "yaw", "pitch", "health", "weapon"}.
var entries: Array[Dictionary] = []
## Último comando do cliente que o anfitrião processou (-1 = nenhum ainda).
var ack: int = -1
## Estado do movimento do personagem do cliente depois do comando `ack` (vazio = não tem).
var own_state := PackedFloat32Array()
var own_ammo: int = 0
var own_reserve: int = 0
var own_weapon: int = 0
var own_reloading: bool = false


## Uma linha da parte comum a partir de um personagem.
static func entry_of(character: Character) -> Dictionary:
	var flags: int = 0
	if character.is_alive:
		flags |= ALIVE
	if character.is_on_rail:
		flags |= ON_RAIL
	if character.is_rail_pulling:
		flags |= RAIL_PULLING
	if not character.is_grounded():
		flags |= AIRBORNE
	if character.is_spawn_protected:
		flags |= PROTECTED
	var weapon: Weapon = character.weapon
	if weapon != null and weapon.is_reloading:
		flags |= RELOADING
	return {
		"id": character.net_id,
		"flags": flags,
		"position": character.global_position,
		"velocity": character.velocity,
		"yaw": character.yaw,
		"pitch": character.pitch,
		"health": roundi(character.health),
		"weapon": NetMessage.weapon_index(weapon.data.id) if weapon != null and weapon.data != null else 0,
	}


## A parte comum em bytes (montada uma vez e usada para todos os clientes).
func encode_entries() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	for entry: Dictionary in entries:
		buffer.put_u8(entry["id"])
		buffer.put_u8(entry["flags"])
		var position: Vector3 = entry["position"]
		buffer.put_float(position.x)
		buffer.put_float(position.y)
		buffer.put_float(position.z)
		var velocity: Vector3 = entry["velocity"]
		buffer.put_half(velocity.x)
		buffer.put_half(velocity.y)
		buffer.put_half(velocity.z)
		buffer.put_half(entry["yaw"])
		buffer.put_half(entry["pitch"])
		buffer.put_u8(clampi(entry["health"], 0, 255))
		buffer.put_u8(entry["weapon"])
	return buffer.data_array


## A foto inteira para um cliente: cabeçalho + parte comum (`entry_bytes`) + a parte dele.
func encode(entry_bytes: PackedByteArray) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(NetMessage.Type.SNAPSHOT)
	buffer.put_u32(tick)
	buffer.put_float(time_left)
	buffer.put_u8(entry_bytes.size() / ENTRY_SIZE)
	buffer.put_data(entry_bytes)
	buffer.put_32(ack)
	buffer.put_u8(own_state.size())
	for value: float in own_state:
		buffer.put_float(value)
	buffer.put_u8(clampi(own_ammo, 0, 255))
	buffer.put_16(clampi(own_reserve, -1, 32767))
	buffer.put_u8(own_weapon)
	buffer.put_u8(int(own_reloading))
	return buffer.data_array


## Lê uma foto (null se o pacote estiver estragado).
static func decode(bytes: PackedByteArray) -> NetSnapshot:
	# Cabeçalho: tipo, passo, relógio, quantos personagens.
	if bytes.size() < 10 or bytes[0] != NetMessage.Type.SNAPSHOT:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(1)
	var snapshot := NetSnapshot.new()
	snapshot.tick = buffer.get_u32()
	snapshot.time_left = buffer.get_float()
	var count: int = buffer.get_u8()
	# Parte comum + ack (4) + tamanho do estado (1).
	if bytes.size() < 10 + count * ENTRY_SIZE + 5:
		return null
	for i: int in count:
		var entry: Dictionary = {}
		entry["id"] = buffer.get_u8()
		entry["flags"] = buffer.get_u8()
		entry["position"] = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
		entry["velocity"] = Vector3(buffer.get_half(), buffer.get_half(), buffer.get_half())
		entry["yaw"] = buffer.get_half()
		entry["pitch"] = buffer.get_half()
		entry["health"] = buffer.get_u8()
		entry["weapon"] = buffer.get_u8()
		snapshot.entries.append(entry)
	snapshot.ack = buffer.get_32()
	var state_size: int = buffer.get_u8()
	if state_size > MAX_OWN_STATE or buffer.get_available_bytes() != state_size * 4 + 5:
		return null
	for i: int in state_size:
		snapshot.own_state.append(buffer.get_float())
	snapshot.own_ammo = buffer.get_u8()
	snapshot.own_reserve = buffer.get_16()
	snapshot.own_weapon = buffer.get_u8()
	snapshot.own_reloading = buffer.get_u8() != 0
	if not is_finite(snapshot.time_left):
		return null
	return snapshot
