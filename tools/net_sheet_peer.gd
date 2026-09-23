extends SceneTree
## Ajudante do `tools/net_sheet.gd`: outro "aparelho" (processo do Godot sem tela) que entra na
## sala aberta pela ferramenta e fica lá alguns segundos, para a foto da sala com dois jogadores.
##   Godot --headless --path . -s res://tools/net_sheet_peer.gd -- <porta> <nome> <segundos>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var port: int = args[0].to_int()
	Settings.player_name = args[1]
	var until: int = Time.get_ticks_msec() + int(args[2].to_float() * 1000.0)
	while Time.get_ticks_msec() < until:
		if not Net.is_online():
			Net.join_lan("127.0.0.1", port)
			root.add_child(NetLobby.new())
		await process_frame
	Net.stop()
	quit()
