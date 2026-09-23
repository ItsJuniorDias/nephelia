class_name NetClient
extends NetGame
## Cliente da partida em rede: o jogador daqui joga na hora (prevê o próprio movimento e o próprio
## tiro), manda os comandos ao anfitrião e mostra o resto como o anfitrião decidiu.
##
## - Previsão: cada comando ganha um número (`tick`) e fica guardado até o anfitrião confirmar.
##   Quando a foto do anfitrião diz onde o personagem estava depois do comando N e isso não bate
##   com o que este aparelho previu, o personagem volta para lá e refaz os comandos seguintes
##   (`Character.reconcile`): a correção é quase sempre invisível.
## - Os outros personagens são marionetes (PuppetController) mostradas um pouco no passado
##   (`render_tick`, 100 ms), passeando suave entre as fotos.
## - Vida, mortes, renascimentos, itens, armas, placar e fim da partida chegam como eventos e são
##   repassados pelos mesmos sinais do juiz e do modo de jogo: HUD, sons e efeitos nem sabem que
##   é rede.

## Os outros aparecem este tanto de passos no passado (100 ms: aguenta uma foto atrasada).
const INTERP_TICKS: float = 6.0
## Diferença de posição (m) entre a previsão e o anfitrião que já pede correção.
const CORRECTION_DISTANCE: float = 0.03
## Comandos guardados no máximo (se o anfitrião parar de confirmar, os velhos saem).
const MAX_PENDING: int = 120

## O jogador deste aparelho.
var local: Character
## Momento (em passos do anfitrião) em que as marionetes são mostradas.
var render_tick: float = 0.0
## Já recebeu o mundo do anfitrião (antes disso não manda comandos).
var has_world: bool = false
## Quantas vezes a previsão precisou ser corrigida (testes e ajuste).
var corrections: int = 0
## Última distância entre a previsão e o anfitrião (m; -1 = não deu para comparar).
var last_prediction_error: float = -1.0
## Últimas correções: [passo da foto, comando confirmado, erro (m), comandos refeitos] (ajuste).
var correction_log: Array[Array] = []

## Relógio: passo do anfitrião estimado agora (anda 1 por passo, puxado pelas fotos).
var _clock: float = 0.0
var _has_clock: bool = false
var _next_command_tick: int = 1
## Comandos mandados e ainda não confirmados (para refazer na correção).
var _pending: Array[CharacterCommand] = []
## Estado previsto do movimento depois de cada comando: {tick do comando: get_move_state}.
var _predicted: Dictionary[int, PackedFloat32Array] = {}
var _last_command_tick: int = -1
## Fotos anteriores a este passo não valem para o jogador daqui (ele renasceu depois).
var _respawn_tick: int = -1
var _latest_snapshot: NetSnapshot
var _last_applied_snapshot_tick: int = -1
var _left: bool = false


func _setup() -> void:
	super._setup()
	referee.authority = false
	deathmatch.authority = false
	deathmatch.waiting = true
	transport.closed.connect(_on_connection_lost)
	# O jogador daqui fica; os outros personagens da cena saem (quem manda neles é o anfitrião).
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.controller is HumanController and local == null:
			local = character
		else:
			character.remove_from_group(&"characters")
			character.remove_from_group(&"bots")
			character.queue_free()
	if local != null:
		local.display_name = Settings.player_name
		local.command_hook = _on_local_command
	transport.send(NetTransport.HOST_ID, NetMessage.pack(NetMessage.Type.READY), true)


func _physics_process(delta: float) -> void:
	# O comando anterior já foi simulado: guarda onde ele deixou o personagem.
	if _last_command_tick >= 0 and local != null and not _predicted.has(_last_command_tick):
		_predicted[_last_command_tick] = local.get_move_state(rails)
	super._physics_process(delta)
	_clock += 1.0
	render_tick = _clock - INTERP_TICKS
	if _latest_snapshot != null and _latest_snapshot.tick != _last_applied_snapshot_tick:
		_apply_snapshot(_latest_snapshot, delta)


# ---------------------------------------------------------------- comandos do jogador daqui

# Chamado pelo personagem daqui a cada passo, com o comando do HumanController.
func _on_local_command(command: CharacterCommand) -> void:
	if not has_world:
		# Ainda sem o mundo: fica parado (o anfitrião ainda nem sabe onde ele está).
		command.reset()
		command.yaw = local.yaw
		command.pitch = local.pitch
		return
	NetMessage.quantize(command)
	command.tick = _next_command_tick
	_next_command_tick += 1
	command.view_tick = render_tick
	_pending.append(command.duplicate_command())
	if _pending.size() > MAX_PENDING:
		_pending.pop_front()
	_last_command_tick = command.tick
	var recent: Array[CharacterCommand] = _pending.slice(maxi(_pending.size() - NetMessage.INPUT_REDUNDANCY, 0))
	transport.send(NetTransport.HOST_ID, NetMessage.pack_input(recent), false)


# ---------------------------------------------------------------- mensagens

func _on_packet(_peer: int, bytes: PackedByteArray) -> void:
	var type: int = NetMessage.type_of(bytes)
	if type == NetMessage.Type.SNAPSHOT:
		var snapshot: NetSnapshot = NetSnapshot.decode(bytes)
		if snapshot != null and (_latest_snapshot == null or snapshot.tick > _latest_snapshot.tick):
			_latest_snapshot = snapshot
		return
	var data: Array = NetMessage.unpack(bytes)
	match type:
		NetMessage.Type.WORLD:
			_on_world(data)
		NetMessage.Type.SHOT:
			_on_shot(data)
		NetMessage.Type.DIED:
			_on_died(data)
		NetMessage.Type.RESPAWNED:
			_on_respawned(data)
		NetMessage.Type.PICKUP:
			_on_pickup(data)
		NetMessage.Type.WEAPON:
			_on_weapon(data)
		NetMessage.Type.SCORE:
			_on_score(data)
		NetMessage.Type.MATCH:
			_on_match(data)
		NetMessage.Type.CHARACTER_ADDED:
			# Antes do mundo chegar, o próprio mundo já traz todo mundo (inclusive quem é este aparelho).
			if has_world and data.size() == 1 and data[0] is Array:
				_add_described(data[0])
		NetMessage.Type.CHARACTER_REMOVED:
			if data.size() == 1 and data[0] is int:
				var gone: Character = character_of(data[0])
				if gone != null and gone != local:
					remove_character(gone)
		NetMessage.Type.REJECT:
			_leave("The host refused: %s" % (str(data[0]) if not data.is_empty() else "?"))


func _on_world(data: Array) -> void:
	if data.size() < 6 or not (data[0] is int and data[1] is Array):
		return
	var own_id: int = data[0]
	if local != null:
		local.net_id = own_id
		characters[own_id] = local
		pass_through_others(local)
	for described: Variant in data[1]:
		if described is Array:
			_add_described(described)
	has_world = true
	# Estado da partida antes do placar (começar zera o placar).
	_on_match([data[2], data[3]])
	_on_score([data[4]])
	var available: Array = data[5] if data[5] is Array else []
	for i: int in mini(available.size(), pickups.size()):
		if not available[i] and pickups[i].is_available:
			pickups[i].take(null)


# Personagem descrito pelo anfitrião: [id, aparelho, nome, visual, cor, vivo].
func _add_described(described: Array) -> void:
	if described.size() < 6 or not (described[0] is int and described[1] is int and described[2] is String
			and described[3] is String and described[4] is Color and described[5] is bool):
		return
	var net_id: int = described[0]
	# Este aparelho nunca vira marionete de si mesmo (ela ficaria em cima do corpo e o empurraria).
	if characters.has(net_id) or net_id <= 0 or net_id > 255 or described[1] == Net.local_id():
		return
	var puppet := PuppetController.new()
	puppet.client = self
	var character: Character = spawn_character(net_id, Settings.clean_name(described[2]), described[3],
			described[4], puppet)
	character.is_bot = described[1] == 0
	NameTag.attach(character)
	# Invisível até a primeira foto dizer onde ele está (senão aparece na origem do mapa).
	character.visible = false
	if not described[5]:
		character.die(null)


func _on_shot(data: Array) -> void:
	if data.size() < 12 or not (data[0] is int and data[2] is Vector3 and data[3] is Vector3
			and data[4] is Vector3 and data[5] is PackedVector3Array and data[6] is PackedVector3Array):
		return
	var shooter: Character = character_of(data[0])
	if shooter == null:
		return
	var result := ShotResult.new()
	result.shooter = shooter
	result.weapon = shooter.weapon
	result.origin = data[2]
	result.direction = data[3]
	result.end_point = data[4]
	result.pellet_points = data[5]
	result.ray_normals = data[6]
	var hit_bits: int = data[7] if data[7] is int else 0
	for i: int in result.ray_normals.size():
		result.ray_hit_character.append(hit_bits & (1 << i) != 0)
	result.hit = data[8] == true
	result.hit_normal = data[9] if data[9] is Vector3 else Vector3.UP
	result.victim = character_of(data[10]) if data[10] is int else null
	result.damage = float(data[11]) if (data[11] is float or data[11] is int) else 0.0
	if shooter == local:
		# O próprio tiro já foi desenhado na hora: do anfitrião só vem a confirmação do acerto.
		if result.victim != null and result.damage > 0.0 and local.weapon != null:
			local.weapon.hit_confirmed.emit(result)
		return
	# Arma certa na mão antes de desenhar (som, clarão e ponta do cano são dela).
	var weapon_id: StringName = NetMessage.weapon_id(data[1] if data[1] is int else 0)
	if shooter.weapon != null and shooter.weapon.data.id != weapon_id:
		shooter.weapon.equip(WeaponCatalog.get_weapon(weapon_id))
	referee.shot_resolved.emit(result)
	if shooter.weapon != null:
		shooter.weapon.fired.emit(result)
	if result.victim != null and result.damage > 0.0:
		result.victim.receive_hit(result)


func _on_died(data: Array) -> void:
	if data.size() < 3 or not (data[0] is int and data[1] is int):
		return
	var victim: Character = character_of(data[0])
	if victim == null or not victim.is_alive:
		return
	var killer: Character = character_of(data[1])
	victim.die(killer)
	if victim == local:
		_pending.clear()
		_predicted.clear()
	referee.character_died.emit(victim, killer)


func _on_respawned(data: Array) -> void:
	if data.size() < 4 or not (data[0] is int and data[1] is Transform3D):
		return
	var character: Character = character_of(data[0])
	if character == null:
		return
	var protection: float = float(data[2]) if (data[2] is float or data[2] is int) else 0.0
	character.respawn(data[1], protection)
	var puppet := character.controller as PuppetController
	if puppet != null:
		puppet.clear()
	if character == local:
		_respawn_tick = data[3] if data[3] is int else _respawn_tick
		_pending.clear()
		_predicted.clear()
	referee.character_respawned.emit(character)


func _on_pickup(data: Array) -> void:
	if data.size() < 3 or not (data[0] is int and data[1] is bool and data[2] is int):
		return
	var index: int = data[0]
	if index < 0 or index >= pickups.size():
		return
	var pickup: Pickup = pickups[index]
	if data[1]:
		if not pickup.is_available:
			pickup.restore()
		return
	var by: Character = character_of(data[2])
	if pickup.is_available:
		pickup.take(by)
	if by != null:
		by.receive_pickup(pickup)
		referee.item_picked.emit(by, pickup)


func _on_weapon(data: Array) -> void:
	if data.size() < 2 or not (data[0] is int and data[1] is int):
		return
	var character: Character = character_of(data[0])
	if character == null or character.weapon == null:
		return
	var weapon_id: StringName = NetMessage.weapon_id(data[1])
	# O jogador daqui já troca sozinho quando a munição acaba (previsão): só troca se for outra.
	if character.weapon.data.id != weapon_id:
		character.weapon.equip(WeaponCatalog.get_weapon(weapon_id))


func _on_score(data: Array) -> void:
	if data.size() < 1 or not data[0] is Array:
		return
	for row: Variant in data[0]:
		if row is Array and (row as Array).size() == 3 and row[0] is int and row[1] is int and row[2] is int:
			var character: Character = character_of(row[0])
			if character != null:
				deathmatch.set_stats(character, row[1], row[2])
	deathmatch.score_changed.emit()


func _on_match(data: Array) -> void:
	if data.size() < 2 or not data[0] is int:
		return
	var state: int = data[0]
	var time_left: float = float(data[1]) if (data[1] is float or data[1] is int) else deathmatch.time_left
	match state:
		NetHost.MatchState.WAITING:
			deathmatch.waiting = true
			deathmatch.time_left = time_left
		NetHost.MatchState.RUNNING:
			if deathmatch.waiting or deathmatch.is_finished:
				# Começou (ou recomeçou): placar zerado, relógio cheio, jogo solto.
				deathmatch.restart()
			deathmatch.time_left = time_left
		NetHost.MatchState.FINISHED:
			deathmatch.time_left = time_left
			deathmatch.finish()


# ---------------------------------------------------------------- foto do estado

func _apply_snapshot(snapshot: NetSnapshot, delta: float) -> void:
	_last_applied_snapshot_tick = snapshot.tick
	tick = snapshot.tick
	# Relógio: segue o anfitrião devagar (sem trancos); longe demais, pula.
	if not _has_clock or absf(snapshot.tick - _clock) > 30.0:
		_clock = snapshot.tick
		_has_clock = true
	else:
		_clock += (snapshot.tick - _clock) * 0.05
	if not deathmatch.waiting and not deathmatch.is_finished:
		deathmatch.time_left = snapshot.time_left
	for entry: Dictionary in snapshot.entries:
		var character: Character = character_of(entry["id"])
		if character == null:
			continue
		if character == local:
			if character.is_alive and entry["health"] != roundi(character.health):
				character.set_health(entry["health"])
			continue
		var puppet := character.controller as PuppetController
		if puppet != null:
			puppet.push_sample(snapshot.tick, entry)
		if character.is_alive and entry["health"] != roundi(character.health):
			character.set_health(entry["health"])
		var weapon_id: StringName = NetMessage.weapon_id(entry["weapon"])
		if character.weapon != null and character.weapon.data.id != weapon_id:
			character.weapon.equip(WeaponCatalog.get_weapon(weapon_id))
	_check_prediction(snapshot, delta)


# Confere a previsão do jogador daqui com o que o anfitrião calculou e corrige se precisar.
func _check_prediction(snapshot: NetSnapshot, delta: float) -> void:
	if local == null or not local.is_alive or snapshot.tick <= _respawn_tick:
		return
	if snapshot.own_state.size() < Character.MOVE_STATE_SIZE:
		return
	var confirmed: int = snapshot.ack
	# Comandos já confirmados não precisam mais ser refeitos.
	while not _pending.is_empty() and _pending[0].tick <= confirmed:
		_pending.pop_front()
	var predicted: PackedFloat32Array = _predicted.get(confirmed, PackedFloat32Array())
	for old: int in _predicted.keys():
		if old <= confirmed:
			_predicted.erase(old)
	# Nada pendente: o estado de agora é o que o anfitrião deveria ter.
	if predicted.is_empty() and _pending.is_empty():
		predicted = local.get_move_state(rails)
	var server_position := Vector3(snapshot.own_state[0], snapshot.own_state[1], snapshot.own_state[2])
	if predicted.is_empty():
		last_prediction_error = -1.0
	else:
		last_prediction_error = Vector3(predicted[0], predicted[1], predicted[2]).distance_to(server_position)
		var same_rail: bool = int(predicted[9]) == int(snapshot.own_state[9])
		if last_prediction_error < CORRECTION_DISTANCE and same_rail:
			_correct_ammo(snapshot)
			return
	corrections += 1
	correction_log.append([snapshot.tick, confirmed, last_prediction_error, _pending.size(),
			Vector3(predicted[0], predicted[1], predicted[2]) if not predicted.is_empty() else Vector3.ZERO,
			server_position, Vector3(snapshot.own_state[3], snapshot.own_state[4], snapshot.own_state[5]),
			Vector3(predicted[3], predicted[4], predicted[5]) if not predicted.is_empty() else Vector3.ZERO,
			int(snapshot.own_state[8]), int(predicted[8]) if not predicted.is_empty() else -1])
	if correction_log.size() > 20:
		correction_log.pop_front()
	local.reconcile(snapshot.own_state, rails, _pending, delta, _record_prediction)
	_correct_ammo(snapshot)


func _record_prediction(command: CharacterCommand) -> void:
	_predicted[command.tick] = local.get_move_state(rails)


# Munição: o anfitrião manda; a previsão só vale enquanto há tiro ainda não confirmado.
func _correct_ammo(snapshot: NetSnapshot) -> void:
	var weapon: Weapon = local.weapon
	if weapon == null or weapon.is_reloading or snapshot.own_reloading:
		return
	if NetMessage.weapon_id(snapshot.own_weapon) != weapon.data.id:
		return
	for command: CharacterCommand in _pending:
		if command.fire or command.reload:
			return
	if weapon.ammo != snapshot.own_ammo or weapon.reserve != snapshot.own_reserve:
		weapon.set_ammo(snapshot.own_ammo, snapshot.own_reserve)


# ---------------------------------------------------------------- saída

func _on_connection_lost() -> void:
	_leave("The host left the match.")


func _leave(reason: String) -> void:
	if _left:
		return
	_left = true
	Net.stop(reason)
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")
