class_name NetGame
extends Node
## Partida em rede dentro da arena. Criada pelo ArenaSetup quando há multiplayer: `NetHost` no
## anfitrião (decide tudo e manda) e `NetClient` nos outros (manda comandos e mostra o que chega).
##
## Aqui fica o que os dois têm em comum: a lista de personagens por número (`net_id`), os
## trilhos e itens na mesma ordem nos dois aparelhos, e a leitura dos pacotes a cada passo de
## física, ANTES dos personagens (prioridade baixa), e mesmo com o jogo pausado (fim de partida).
##
## Na rede os personagens NÃO se bloqueiam (passam um pelo outro; os tiros continuam acertando):
## no cliente os outros aparecem 100 ms no passado, então um esbarrão que o anfitrião viu e o
## cliente não virava correção da previsão a cada passo (medido: 0,7 m de erro).

## Personagem base (corpo, arma, cabeça) para jogadores de fora e marionetes.
const CHARACTER_SCENE: PackedScene = preload("res://characters/character.tscn")
## Visual dos jogadores humanos (boina); a cor muda por jogador.
const HUMAN_LOOK := "res://characters/looks/player.tres"
## Uma cor por vaga de jogador humano (tinge a roupa).
const HUMAN_COLORS: Array[Color] = [Color(0.85, 0.85, 0.8), Color(0.35, 0.5, 0.85), Color(0.55, 0.75, 0.35),
		Color(0.8, 0.45, 0.7), Color(0.9, 0.55, 0.25), Color(0.45, 0.8, 0.8)]
## A foto do estado sai a cada tantos passos de física (60 / 2 = 30 por segundo).
const SNAPSHOT_EVERY: int = 2

var transport: NetTransport
var referee: MatchReferee
var deathmatch: Deathmatch
## Onde os personagens ficam (a raiz da arena; o ArenaSetup passa, senão o pai).
var level: Node
## Personagens por número de rede.
var characters: Dictionary[int, Character] = {}
## Trilhos e itens da arena, na mesma ordem em todos os aparelhos (a rede manda o índice).
var rails: Array[SkylineRail] = []
var pickups: Array[Pickup] = []
## Passo de física do anfitrião (no cliente, o último que chegou numa foto).
var tick: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	transport = Net.transport
	if level == null:
		level = get_parent()
	transport.packet_received.connect(_on_packet)
	# Os outros nós da arena ficam prontos depois deste: o resto no fim do quadro.
	_setup.call_deferred()


func _exit_tree() -> void:
	if transport != null and transport.packet_received.is_connected(_on_packet):
		transport.packet_received.disconnect(_on_packet)


func _setup() -> void:
	referee = MatchReferee.find(self)
	deathmatch = Deathmatch.find(self)
	for node: Node in get_tree().get_nodes_in_group(SkylineRail.GROUP):
		rails.append(node as SkylineRail)
	rails.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	for node: Node in get_tree().get_nodes_in_group(Pickup.GROUP):
		pickups.append(node as Pickup)
	pickups.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))


func _physics_process(_delta: float) -> void:
	if transport != null and transport == Net.transport:
		Net.poll()
	elif transport != null:
		transport.poll()


## Personagem pelo número (null se não existe ou já saiu).
func character_of(net_id: int) -> Character:
	var found: Variant = characters.get(net_id)
	if found == null or not is_instance_valid(found):
		return null
	return found as Character


## Número de um personagem (0 = nenhum).
static func id_of(character: Character) -> int:
	return character.net_id if character != null and is_instance_valid(character) else 0


## O trilho mais perto de quem está pendurado em `hang_position` (marionetes: a foto só diz
## "pendurado", não em qual).
func nearest_rail(hang_position: Vector3) -> SkylineRail:
	var best: SkylineRail = null
	var best_distance: float = INF
	var grip: Vector3 = hang_position + Vector3.UP * Character.RAIL_HANG
	for rail: SkylineRail in rails:
		var distance: float = rail.point_at(rail.closest_offset(grip)).distance_to(grip)
		if distance < best_distance:
			best_distance = distance
			best = rail
	return best


## Descrição de um personagem para os clientes: [id, aparelho (0 = bot), nome, visual, cor, vivo].
func describe(character: Character, peer: int) -> Array:
	var look_path: String = character.look.resource_path if character.look != null else ""
	return [character.net_id, peer, character.display_name, look_path, character.body_color,
			character.is_alive]


## Personagem novo (jogador de fora ou marionete), já na arena. `controller` vira filho dele.
func spawn_character(net_id: int, display_name: String, look_path: String, color: Color,
		controller: CharacterController) -> Character:
	var character: Character = CHARACTER_SCENE.instantiate()
	character.name = "Net%d" % net_id
	character.display_name = display_name
	# Só visuais do próprio jogo (o nome vem pela rede: nada de carregar arquivo qualquer).
	if look_path.begins_with("res://characters/looks/") and look_path.ends_with(".tres") \
			and ResourceLoader.exists(look_path):
		character.look = load(look_path) as CharacterLook
	character.body_color = color
	controller.name = controller.get_script().get_global_name()
	character.add_child(controller)
	level.add_child(character)
	character.net_id = net_id
	characters[net_id] = character
	pass_through_others(character)
	return character


## Este personagem passa pelos outros (e eles por ele), sem esbarrar.
func pass_through_others(character: Character) -> void:
	for id: int in characters:
		var other: Character = character_of(id)
		if other != null and other != character:
			character.add_collision_exception_with(other)
			other.add_collision_exception_with(character)


## Tira um personagem da partida (saiu, ou o bot deu a vaga para um jogador).
func remove_character(character: Character) -> void:
	characters.erase(character.net_id)
	if referee != null:
		referee.forget(character)
	if deathmatch != null:
		deathmatch.forget(character)
		deathmatch.score_changed.emit()
	character.remove_from_group(&"characters")
	character.queue_free()


# Cada filha trata as mensagens dela.
func _on_packet(_peer: int, _bytes: PackedByteArray) -> void:
	pass
