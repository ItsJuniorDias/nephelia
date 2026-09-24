class_name DedicatedServer
extends Node
## Servidor dedicado de uma partida online: o jogo sem tela e sem jogador, aberto pelo matchmaker
## (projeto separado `nephelia-server`, em Node.js) assim:
##   Godot --headless --path <jogo> -- --server --port=24700 --match-id=m1 --max-players=4
##       [--transport=websocket --bind=127.0.0.1]
## (no servidor: `godot --headless --main-pack nephelia_server.pck -- --server ...`). Com
## `--transport=websocket` a partida é por WebSocket (Render: o matchmaker repassa as conexões de
## wss://.../play/<partida> para esta porta, só na própria máquina); sem ele, ENet (UDP).
##
## Hospeda a partida (NetHost com `Net.dedicated`: sem jogador daqui) e conta ao matchmaker, pela
## saída padrão, uma linha por evento que começa com "NEPHELIA " (o resto é log do Godot):
##   NEPHELIA {"event":"ready","port":24700,"version":1}        pronto para receber gente
##   NEPHELIA {"event":"status","humans":2,"state":"running","time_left":123.4}   a cada 2 s
##   NEPHELIA {"event":"bye","reason":"..."}                    vai fechar
## O matchmaker fecha a partida (sinal do sistema) quando ela fica vazia por muito tempo.
## Precisa de `application/run/flush_stdout_on_print` ligado no servidor exportado (senão as linhas
## ficam presas no buffer da saída).

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const LINE_PREFIX := "NEPHELIA "
const STATUS_EVERY: float = 2.0
const STATE_NAMES: Array[String] = ["waiting", "running", "finished"]

var port: int = NetMessage.PORT
var match_id: String = "local"

var _host: NetHost
var _ready_sent: bool = false
var _status_timer: float = 0.0
var _last_status: String = ""


## O jogo foi aberto como servidor (argumento --server ou servidor exportado).
static func requested() -> bool:
	return "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")


## Valor de um argumento "--nome=valor" depois do "--" (ou `default`).
static func option(option_name: String, default: String) -> String:
	var prefix: String = "--%s=" % option_name
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default


## Liga o servidor: fica na raiz da árvore (sobrevive à troca de cena) e abre a arena.
static func boot(tree: SceneTree) -> void:
	var server := DedicatedServer.new()
	server.name = "DedicatedServer"
	tree.root.add_child.call_deferred(server)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	port = option("port", str(NetMessage.PORT)).to_int()
	match_id = option("match-id", "local")
	var wanted_players: int = option("max-players", str(Net.MAX_PLAYERS)).to_int()
	if wanted_players != Net.MAX_PLAYERS:
		push_warning("max-players %d pedido; este jogo aceita %d" % [wanted_players, Net.MAX_PLAYERS])
	var websocket: bool = option("transport", "enet") == "websocket"
	var err: Error = Net.host_dedicated(port, websocket, option("bind", "*"))
	if err != OK:
		emit_event({"event": "bye", "reason": "could not open port %d (%s)" % [port, error_string(err)]})
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file(ARENA)


func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		_host = null
		var scene: Node = get_tree().current_scene
		if scene != null:
			_host = scene.find_child("NetHost", true, false) as NetHost
		if _host == null or not _host.is_setup:
			return
	if not _ready_sent:
		_ready_sent = true
		emit_event({"event": "ready", "port": port, "version": NetMessage.VERSION})
	_status_timer -= delta
	var status: Dictionary = {"event": "status", "humans": _host.players.size(),
			"state": STATE_NAMES[_host.match_state()]}
	var summary: String = JSON.stringify(status)
	# Manda na hora quando muda (alguém entrou/saiu) e de tempos em tempos (sinal de vida).
	if summary != _last_status or _status_timer <= 0.0:
		_last_status = summary
		_status_timer = STATUS_EVERY
		status["time_left"] = snappedf(_host.deathmatch.time_left, 0.1)
		emit_event(status)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _ready_sent:
			emit_event({"event": "bye", "reason": "closing"})


## Uma linha de evento para o matchmaker.
static func emit_event(event: Dictionary) -> void:
	print(LINE_PREFIX + JSON.stringify(event))
