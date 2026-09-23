class_name Lobby
extends Control
## Sala do multiplayer no menu (Wi-Fi local): escolher o nome, hospedar ou entrar pelo endereço
## do anfitrião, ver quem está na sala e começar. Quem cuida da conversa é o `NetLobby`.
##
## A tela é montada por `tools/make_menus.gd`. Quando uma partida em rede acaba mal (o anfitrião
## saiu), o menu inicial abre esta tela com o motivo (`Net.last_error`).

signal closed

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const ERROR_COLOR := Color(1.0, 0.55, 0.45)
const INFO_COLOR := Color(0.94, 0.87, 0.7)

var _room: NetLobby

@onready var name_edit: LineEdit = $Panel/Rows/NameRow/NameEdit
@onready var host_button: Button = $Panel/Rows/HostButton
@onready var join_row: HBoxContainer = $Panel/Rows/JoinRow
@onready var address_edit: LineEdit = $Panel/Rows/JoinRow/AddressEdit
@onready var join_button: Button = $Panel/Rows/JoinRow/JoinButton
@onready var info_label: Label = $Panel/Rows/Info
@onready var players_box: VBoxContainer = $Panel/Rows/Players
@onready var start_button: Button = $Panel/Rows/StartButton
@onready var status_label: Label = $Panel/Rows/Status
@onready var back_button: Button = $Panel/Rows/BackButton


func _ready() -> void:
	visible = false
	name_edit.max_length = 14
	name_edit.text = Settings.player_name
	name_edit.text_changed.connect(func(_text: String) -> void: _save_name())
	address_edit.text = Settings.last_address
	address_edit.text_submitted.connect(func(_text: String) -> void: _on_join())
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	Sounds.wire_buttons(self)


## Abre a sala; `message` aparece embaixo (ex.: por que a última partida acabou).
func open(message: String = "") -> void:
	visible = true
	_show_status(message, not message.is_empty())
	_refresh()
	host_button.grab_focus()


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


func _on_join() -> void:
	_save_name()
	var address: String = address_edit.text.strip_edges()
	if address.is_empty():
		_show_status("Type the host's address (it is shown on the host's screen).", true)
		address_edit.grab_focus()
		return
	Settings.set_option(&"last_address", address)
	if Net.join_lan(address) != OK:
		_show_status("That address does not look right.", true)
		return
	_show_status("Connecting to %s..." % address)
	_open_room()


func _on_start() -> void:
	if _room != null:
		_room.start_match()


func _on_back() -> void:
	if Net.is_online():
		# Sai da sala (o anfitrião saindo fecha a sala de todos).
		_close_room()
		Net.stop()
		_show_status("")
		_refresh()
		host_button.grab_focus()
		return
	visible = false
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
	join_row.visible = not online
	info_label.visible = in_room
	if hosting:
		var addresses: PackedStringArray = Net.local_addresses()
		info_label.text = "On the same Wi-Fi, friends join with:  %s" % (
				"  or  ".join(addresses) if not addresses.is_empty() else "this device's address")
	elif in_room:
		info_label.text = "Waiting for the host to start the match..."
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
	start_button.visible = hosting
	start_button.disabled = Net.roster.size() < 2
	start_button.text = "START MATCH" if Net.roster.size() >= 2 else "WAITING FOR PLAYERS"
	back_button.text = "LEAVE ROOM" if online else "BACK"
