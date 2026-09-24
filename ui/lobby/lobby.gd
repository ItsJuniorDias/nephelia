class_name Lobby
extends Control
## Sala do multiplayer no menu (Wi-Fi local): escolher o nome, hospedar ou entrar numa sala achada
## no mesmo Wi-Fi (LanScanner: ninguém digita endereço) e ver quem está na sala. Não tem botão de
## começar: assim que alguém entra, a partida começa sozinha depois de uma contagem curta
## (`NetLobby`, que cuida da conversa).
##
## A tela é montada por `tools/make_menus.gd`. Quando uma partida em rede acaba mal (o anfitrião
## saiu), o menu inicial abre esta tela com o motivo (`Net.last_error`).

signal closed

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const ERROR_COLOR := Color(1.0, 0.55, 0.45)
const INFO_COLOR := Color(0.94, 0.87, 0.7)

## Tamanho dos botões das salas achadas.
const ROOM_BUTTON_HEIGHT: float = 64.0

var _room: NetLobby
var _scanner := LanScanner.new()

@onready var name_edit: LineEdit = $Panel/Rows/NameRow/NameEdit
@onready var host_button: Button = $Panel/Rows/HostButton
@onready var rooms_title: Label = $Panel/Rows/RoomsTitle
@onready var rooms_box: VBoxContainer = $Panel/Rows/Rooms
@onready var searching_label: Label = $Panel/Rows/Searching
@onready var info_label: Label = $Panel/Rows/Info
@onready var players_box: VBoxContainer = $Panel/Rows/Players
@onready var status_label: Label = $Panel/Rows/Status
@onready var back_button: Button = $Panel/Rows/BackButton


func _ready() -> void:
	visible = false
	name_edit.max_length = 14
	name_edit.text = Settings.player_name
	name_edit.text_changed.connect(func(_text: String) -> void: _save_name())
	host_button.pressed.connect(_on_host)
	_scanner.rooms_changed.connect(_refresh_rooms)
	back_button.pressed.connect(_on_back)
	Sounds.wire_buttons(self)


## Abre a sala; `message` aparece embaixo (ex.: por que a última partida acabou).
func open(message: String = "") -> void:
	visible = true
	_show_status(message, not message.is_empty())
	_update_search()
	_refresh()
	host_button.grab_focus()


func _process(_delta: float) -> void:
	_scanner.poll()


func _exit_tree() -> void:
	_scanner.stop()


## Salas achadas no Wi-Fi agora (testes).
func get_room_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in rooms_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons.append(child as Button)
	return buttons


func is_open() -> bool:
	return visible


## Nomes na lista da sala (testes).
func get_player_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for child: Node in players_box.get_children():
		if not child.is_queued_for_deletion():
			lines.append((child as Label).text)
	return lines


func _on_host() -> void:
	_save_name()
	var err: Error = Net.host_lan(Settings.player_name)
	if err != OK:
		_show_status("Could not open the room on this device.", true)
		return
	_show_status("")
	_open_room()


# Entra na sala que o LanScanner achou (endereço e porta vêm da resposta do anfitrião).
func _join_room(room: Dictionary) -> void:
	_save_name()
	if Net.join_lan(room["address"], room["port"]) != OK:
		_show_status("Could not reach that game.", true)
		return
	_show_status("Joining %s's game..." % room["host"])
	MemeSounds.play_joining(self)
	_open_room()


func _on_back() -> void:
	if Net.is_online():
		# Sai da sala (o anfitrião saindo fecha a sala de todos).
		_close_room()
		Net.stop()
		_show_status("")
		_update_search()
		_refresh()
		host_button.grab_focus()
		return
	visible = false
	_update_search()
	closed.emit()


func _open_room() -> void:
	_close_room()
	_room = NetLobby.new()
	_room.name = "NetLobby"
	add_child(_room)
	_room.roster_changed.connect(_refresh)
	_room.joined.connect(_on_joined)
	_room.failed.connect(_on_failed)
	_room.match_starting.connect(_on_match_starting)
	_room.countdown_changed.connect(_refresh.unbind(1))
	_update_search()
	_refresh()
	back_button.grab_focus()


func _close_room() -> void:
	if _room != null:
		_room.queue_free()
		_room = null


func _on_joined() -> void:
	_show_status("")
	_refresh()


func _on_failed(reason: String) -> void:
	_close_room()
	_show_status(reason, true)
	_update_search()
	_refresh()


func _on_match_starting() -> void:
	get_tree().change_scene_to_file(ARENA)


func _save_name() -> void:
	if Settings.clean_name(name_edit.text) != Settings.player_name:
		Settings.set_option(&"player_name", name_edit.text)


func _show_status(text: String, is_error: bool = false) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()
	status_label.add_theme_color_override(&"font_color", ERROR_COLOR if is_error else INFO_COLOR)


func _refresh() -> void:
	var online: bool = Net.is_online()
	var hosting: bool = Net.is_host()
	var in_room: bool = hosting or (Net.is_client() and Net.roster.has(Net.local_id()))
	name_edit.editable = not online
	host_button.visible = not online
	rooms_title.visible = not online
	rooms_box.visible = not online
	searching_label.visible = not online and _scanner.rooms.is_empty()
	info_label.visible = in_room
	var countdown: int = _room.seconds_to_start() if _room != null else -1
	if hosting and countdown >= 0:
		info_label.text = "Starting in %d..." % maxi(countdown, 1)
	elif hosting:
		info_label.text = "Waiting for a friend to join.\nOn the same Wi-Fi, they open MULTIPLAYER and tap your game."
	elif in_room:
		info_label.text = "You are in! The match starts in a moment..."
	for child: Node in players_box.get_children():
		players_box.remove_child(child)
		child.queue_free()
	players_box.visible = in_room
	if in_room:
		var peers: Array[int] = Net.roster.keys()
		peers.sort()
		for peer: int in peers:
			var line := Label.new()
			line.theme_type_variation = &"HudTag"
			var role: String = "  (HOST)" if peer == NetTransport.HOST_ID else ""
			var me: String = "  (YOU)" if peer == Net.local_id() else ""
			line.text = "%s%s%s" % [Net.roster[peer], role, me]
			players_box.add_child(line)
		# Vagas vazias viram bots na partida.
		var free_slots: int = maxi(Net.MIN_CHARACTERS - Net.roster.size(), 0)
		if free_slots > 0:
			var bots := Label.new()
			bots.text = "+ %d bot%s to fill the arena" % [free_slots, "" if free_slots == 1 else "s"]
			bots.add_theme_color_override(&"font_color", NameTag.BOT_COLOR)
			players_box.add_child(bots)
	back_button.text = "LEAVE ROOM" if online else "BACK"


# Procura salas só com a tela aberta e fora de uma sala (no iPhone, a primeira procura pede a
# permissão de rede local).
func _update_search() -> void:
	if visible and not Net.is_online():
		if not _scanner.is_running():
			_scanner.start()
	else:
		_scanner.stop()
	_refresh_rooms()


# Um botão por sala achada: "JOIN ALEX'S GAME", com quantos já estão e se já está jogando.
func _refresh_rooms() -> void:
	for child: Node in rooms_box.get_children():
		rooms_box.remove_child(child)
		child.queue_free()
	for room: Dictionary in _scanner.room_list():
		var button := Button.new()
		button.theme_type_variation = &"TitleButton"
		button.custom_minimum_size = Vector2(0, ROOM_BUTTON_HEIGHT)
		var full: bool = int(room["players"]) >= int(room["max_players"])
		var state: String = "FULL" if full else ("PLAYING" if room["in_match"] else "%d/%d" % [room["players"],
				room["max_players"]])
		button.text = "JOIN %s'S GAME  (%s)" % [str(room["host"]).to_upper(), state]
		button.disabled = full
		button.pressed.connect(_join_room.bind(room))
		rooms_box.add_child(button)
	Sounds.wire_buttons(rooms_box)
	searching_label.visible = visible and not Net.is_online() and _scanner.rooms.is_empty()
