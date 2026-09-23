class_name NetHost
extends NetGame
## Anfitrião da partida em rede: é o servidor. Roda o juiz de verdade e simula todos os
## personagens (os de fora com os comandos que chegam, pelo RemoteController). Manda a foto do
## estado 30 vezes por segundo e avisa cada evento: tiro, morte, renascimento, item, arma, placar
## e fim da partida.
##
## Jogadores entram pela sala (menu) ou no meio da partida (mandam HELLO aqui). Bots completam as
## vagas até `Net.MIN_CHARACTERS`: quem entra toma a vaga de um bot, quem sai devolve.
##
## Compensação do atraso: guarda onde cada personagem estava nos últimos passos e, no tiro de um
## jogador de fora, volta os alvos para onde ELE os via (`_rewind`), como nos jogos de tiro de PC.

## Vagas dos bots, na ordem em que entram (os mesmos da arena).
const BOTS: Array[Dictionary] = [
	{"name": "Hazel", "look": "res://characters/looks/hazel.tres", "color": Color(0.76, 0.38, 0.24)},
	{"name": "Otis", "look": "res://characters/looks/otis.tres", "color": Color(0.22, 0.55, 0.6)},
	{"name": "Mabel", "look": "res://characters/looks/mabel.tres", "color": Color(0.85, 0.68, 0.2)},
]
const BOT_SCENE: PackedScene = preload("res://bots/bot.tscn")
## Espera os jogadores carregarem a arena no máximo este tempo antes de começar sem eles.
const READY_TIMEOUT: float = 20.0
## Passos guardados de onde cada um estava (compensação do atraso).
const HISTORY_TICKS: int = 40
## Volta no máximo este tanto no tempo para decidir um tiro (300 ms).
const MAX_REWIND_TICKS: float = 18.0
## Jogador de fora com mais comandos que isso na fila anda um passo extra (alcança o atraso).
const CATCH_UP_QUEUE: int = 1
## Passos extras por passo de física, no máximo.
const MAX_CATCH_UP_STEPS: int = 2

enum MatchState { WAITING, RUNNING, FINISHED }

## Jogadores de fora: {aparelho: {"name": String, "character": Character, "ready": bool}}.
var players: Dictionary[int, Dictionary] = {}
var local_character: Character

var _next_id: int = 1
var _wait_timer: float = 0.0
## Onde cada personagem vivo estava no fim de cada passo: {passo: {personagem: posição}}.
var _history: Dictionary[int, Dictionary] = {}
## Passo em que cada personagem renasceu (não dá para voltar ao corpo antigo).
var _respawn_ticks: Dictionary[Character, int] = {}
## Posições de verdade guardadas durante um tiro compensado.
var _rewound: Dictionary[Character, Vector3] = {}


func _setup() -> void:
	super._setup()
	referee.shot_rewinder = _rewind
	referee.shot_resolved.connect(_on_shot_resolved)
	referee.character_died.connect(_on_character_died)
	referee.character_respawned.connect(_on_character_respawned)
	referee.item_picked.connect(_on_item_picked)
	for i: int in pickups.size():
		pickups[i].restored.connect(_on_pickup_restored.bind(i))
	deathmatch.score_changed.connect(_send_score)
	deathmatch.match_started.connect(_send_match_state)
	deathmatch.match_finished.connect(_on_match_finished.unbind(1))
	transport.peer_left.connect(_remove_player)

	# O jogador daqui e os bots da cena ganham número; os de fora entram com um personagem novo.
	var scene_bots: Array[Character] = []
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.controller is HumanController and local_character == null:
			local_character = character
		elif character.controller is BotController:
			scene_bots.append(character)
	if local_character != null:
		local_character.display_name = Net.roster.get(NetTransport.HOST_ID, Settings.player_name)
		_register(local_character)
	for bot: Character in scene_bots:
		_register(bot)
	for peer: int in Net.roster:
		if peer != NetTransport.HOST_ID:
			_add_player(peer, Net.roster[peer])
	_balance_bots()

	# Espera quem veio da sala carregar a arena (o relógio não anda até lá).
	deathmatch.waiting = not players.is_empty()
	_wait_timer = READY_TIMEOUT


func _physics_process(delta: float) -> void:
	# Fim do passo anterior: guarda onde estavam (compensação) e manda a foto.
	_record_history()
	if tick % SNAPSHOT_EVERY == 0:
		_send_snapshots()
	tick += 1
	# Comandos que chegaram entram agora, antes de os personagens andarem (prioridade baixa).
	super._physics_process(delta)
	_catch_up(delta)
	if deathmatch != null and deathmatch.waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_start_match()


# Comandos acumulados (a rede entregou vários de uma vez): passos extras até a fila voltar a um.
# O passo normal do personagem vem depois, com o comando que sobrou.
func _catch_up(delta: float) -> void:
	if get_tree().paused:
		return
	for peer: int in players:
		var character: Character = players[peer]["character"]
		if not is_instance_valid(character):
			continue
		var remote := character.controller as RemoteController
		var steps: int = 0
		while remote != null and remote.queued() > CATCH_UP_QUEUE and steps < MAX_CATCH_UP_STEPS \
				and character.is_alive:
			character.simulate(delta)
			steps += 1


## Estado da partida mandado para os clientes.
func match_state() -> MatchState:
	if deathmatch.is_finished:
		return MatchState.FINISHED
	return MatchState.WAITING if deathmatch.waiting else MatchState.RUNNING


# ---------------------------------------------------------------- jogadores e vagas

func _register(character: Character) -> void:
	character.net_id = _next_id
	_next_id += 1
	characters[character.net_id] = character
	pass_through_others(character)
	_watch(character)


func _watch(character: Character) -> void:
	if character.weapon != null:
		character.weapon.weapon_changed.connect(_on_weapon_changed.bind(character))


func _add_player(peer: int, player_name: String) -> Character:
	var remote := RemoteController.new()
	remote.peer = peer
	var color: Color = HUMAN_COLORS[(players.size() + 1) % HUMAN_COLORS.size()]
	var character: Character = spawn_character(_next_id, player_name, HUMAN_LOOK, color, remote)
	_next_id += 1
	_watch(character)
	players[peer] = {"name": player_name, "character": character, "ready": false}
	_broadcast(NetMessage.Type.CHARACTER_ADDED, [describe(character, peer)])
	referee.respawn_now(character)
	return character


func _remove_player(peer: int) -> void:
	Net.roster.erase(peer)
	if not players.has(peer):
		return
	var info: Dictionary = players[peer]
	players.erase(peer)
	var character: Character = info["character"]
	if is_instance_valid(character):
		_broadcast(NetMessage.Type.CHARACTER_REMOVED, [character.net_id])
		remove_character(character)
	_balance_bots()
	_check_all_ready()


# Bots completam as vagas: sai um quando entra jogador, volta um quando jogador sai.
func _balance_bots() -> void:
	var wanted: int = maxi(Net.MIN_CHARACTERS - 1 - players.size(), 0)
	var bots: Array[Character] = []
	for id: int in characters:
		var character: Character = character_of(id)
		if character != null and character.controller is BotController:
			bots.append(character)
	while bots.size() > wanted:
		var leaving: Character = bots.pop_back()
		_broadcast(NetMessage.Type.CHARACTER_REMOVED, [leaving.net_id])
		remove_character(leaving)
	while bots.size() < wanted:
		var added: Character = _add_bot(bots)
		if added == null:
			break
		bots.append(added)


func _add_bot(existing: Array[Character]) -> Character:
	var used: Array[String] = []
	for bot: Character in existing:
		used.append(bot.display_name)
	for slot: Dictionary in BOTS:
		if slot["name"] in used:
			continue
		var bot: Character = BOT_SCENE.instantiate()
		bot.name = slot["name"]
		bot.display_name = slot["name"]
		bot.look = load(slot["look"]) as CharacterLook
		bot.body_color = slot["color"]
		level.add_child(bot)
		var brain := bot.controller as BotController
		if brain != null:
			brain.random_seed = BOTS.find(slot) + 1
			var difficulty: BotDifficulty = Settings.difficulty_resource()
			if difficulty != null:
				brain.difficulty = difficulty
		_register(bot)
		_broadcast(NetMessage.Type.CHARACTER_ADDED, [describe(bot, 0)])
		referee.respawn_now(bot)
		return bot
	return null


func _check_all_ready() -> void:
	if not deathmatch.waiting:
		return
	for peer: int in players:
		if not players[peer]["ready"]:
			return
	_start_match()


func _start_match() -> void:
	# restart(): zera placar e relógio, faz todos renascerem e avisa (match_started).
	deathmatch.restart()


# ---------------------------------------------------------------- mensagens

func _on_packet(peer: int, bytes: PackedByteArray) -> void:
	match NetMessage.type_of(bytes):
		NetMessage.Type.INPUT:
			var info: Dictionary = players.get(peer, {})
			if info.is_empty() or not is_instance_valid(info["character"]):
				return
			var remote := (info["character"] as Character).controller as RemoteController
			if remote != null:
				remote.push(NetMessage.unpack_input(bytes))
		NetMessage.Type.HELLO:
			_on_hello(peer, NetMessage.unpack(bytes))
		NetMessage.Type.READY:
			_on_ready(peer)
		NetMessage.Type.LEAVE:
			_remove_player(peer)


# Alguém entrou no meio da partida: ganha um personagem (no lugar de um bot) e carrega a arena.
func _on_hello(peer: int, data: Array) -> void:
	var problem: String = Net.check_hello(data, players.size() + 1)
	if not problem.is_empty():
		transport.send(peer, NetMessage.pack(NetMessage.Type.REJECT, [problem]), true)
		return
	var player_name: String = Settings.clean_name(data[1])
	Net.roster[peer] = player_name
	if not players.has(peer):
		_add_player(peer, player_name)
		_balance_bots()
	transport.send(peer, NetMessage.pack(NetMessage.Type.START, []), true)


# O jogador carregou a arena: recebe o mundo inteiro e passa a receber as fotos.
func _on_ready(peer: int) -> void:
	if not players.has(peer):
		return
	var info: Dictionary = players[peer]
	info["ready"] = true
	transport.send(peer, NetMessage.pack(NetMessage.Type.WORLD, _world_for(peer)), true)
	_check_all_ready()


func _world_for(peer: int) -> Array:
	var described: Array = []
	for id: int in characters:
		var character: Character = character_of(id)
		if character != null:
			described.append(describe(character, _peer_of(character)))
	var available: Array = []
	for pickup: Pickup in pickups:
		available.append(pickup.is_available)
	var own: Character = players[peer]["character"]
	return [own.net_id, described, match_state(), deathmatch.time_left, _score_rows(), available]


func _peer_of(character: Character) -> int:
	if character == local_character:
		return NetTransport.HOST_ID
	var remote := character.controller as RemoteController
	return remote.peer if remote != null else 0


func _broadcast(type: NetMessage.Type, data: Array, reliable: bool = true) -> void:
	transport.send(0, NetMessage.pack(type, data), reliable)


# ---------------------------------------------------------------- foto do estado

func _send_snapshots() -> void:
	var snapshot := NetSnapshot.new()
	snapshot.tick = tick
	snapshot.time_left = deathmatch.time_left
	for id: int in characters:
		var character: Character = character_of(id)
		if character != null:
			snapshot.entries.append(NetSnapshot.entry_of(character))
	var shared: PackedByteArray = snapshot.encode_entries()
	for peer: int in players:
		var info: Dictionary = players[peer]
		var character: Character = info["character"]
		if not info["ready"] or not is_instance_valid(character):
			continue
		var remote := character.controller as RemoteController
		snapshot.ack = remote.last_tick if remote != null else -1
		snapshot.own_state = character.get_move_state(rails)
		var weapon: Weapon = character.weapon
		snapshot.own_ammo = weapon.ammo
		snapshot.own_reserve = weapon.reserve
		snapshot.own_weapon = NetMessage.weapon_index(weapon.data.id)
		snapshot.own_reloading = weapon.is_reloading
		transport.send(peer, snapshot.encode(shared), false)


func _record_history() -> void:
	var positions: Dictionary[Character, Vector3] = {}
	for id: int in characters:
		var character: Character = character_of(id)
		if character != null and character.is_alive:
			positions[character] = character.global_position
	_history[tick] = positions
	_history.erase(tick - HISTORY_TICKS)


# Tiro de um jogador de fora: os outros voltam para onde ele os via (`begin`) e depois voltam
# para onde estão de verdade.
func _rewind(shooter: Character, begin: bool) -> void:
	if not begin:
		for character: Character in _rewound:
			if is_instance_valid(character):
				character.global_position = _rewound[character]
		_rewound.clear()
		return
	var remote := shooter.controller as RemoteController
	if remote == null:
		return
	# O último passo guardado é o anterior (este ainda está sendo simulado).
	var latest: float = tick - 1
	var view: float = clampf(remote.view_tick, latest - MAX_REWIND_TICKS, latest)
	var before: int = floori(view)
	var weight: float = view - before
	for id: int in characters:
		var character: Character = character_of(id)
		if character == null or character == shooter or not character.is_alive:
			continue
		if _respawn_ticks.get(character, -1) > before:
			continue
		var from: Dictionary = _history.get(before, {})
		if not from.has(character):
			continue
		var to: Dictionary = _history.get(before + 1, {})
		var then: Vector3 = (from[character] as Vector3).lerp(to.get(character, from[character]), weight)
		_rewound[character] = character.global_position
		character.global_position = then


# ---------------------------------------------------------------- eventos

func _on_shot_resolved(result: ShotResult) -> void:
	var hit_bits: int = 0
	for i: int in mini(result.ray_hit_character.size(), 31):
		if result.ray_hit_character[i]:
			hit_bits |= 1 << i
	var weapon_index: int = NetMessage.weapon_index(result.weapon.data.id) \
			if result.weapon != null and result.weapon.data != null else 0
	_broadcast(NetMessage.Type.SHOT, [id_of(result.shooter), weapon_index, result.origin, result.direction,
			result.end_point, result.pellet_points, result.ray_normals, hit_bits, result.hit,
			result.hit_normal, id_of(result.victim), result.damage])


func _on_character_died(victim: Character, killer: Character) -> void:
	_broadcast(NetMessage.Type.DIED, [id_of(victim), id_of(killer), tick])


func _on_character_respawned(character: Character) -> void:
	_respawn_ticks[character] = tick
	var remote := character.controller as RemoteController
	if remote != null:
		remote.clear()
	_broadcast(NetMessage.Type.RESPAWNED, [character.net_id, character.global_transform,
			referee.spawn_protection_time if character.is_spawn_protected else 0.0, tick])


func _on_item_picked(character: Character, pickup: Pickup) -> void:
	_broadcast(NetMessage.Type.PICKUP, [pickups.find(pickup), false, id_of(character)])


func _on_pickup_restored(index: int) -> void:
	_broadcast(NetMessage.Type.PICKUP, [index, true, 0])


func _on_weapon_changed(data: WeaponData, character: Character) -> void:
	if character.net_id > 0:
		_broadcast(NetMessage.Type.WEAPON, [character.net_id, NetMessage.weapon_index(data.id)])


func _score_rows() -> Array:
	var rows: Array = []
	for id: int in characters:
		var character: Character = character_of(id)
		if character != null:
			rows.append([id, deathmatch.get_kills(character), deathmatch.get_deaths(character)])
	return rows


func _send_score() -> void:
	_broadcast(NetMessage.Type.SCORE, [_score_rows()])


func _send_match_state() -> void:
	_broadcast(NetMessage.Type.MATCH, [match_state(), deathmatch.time_left])


func _on_match_finished() -> void:
	_send_score()
	_send_match_state()
