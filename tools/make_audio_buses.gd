extends SceneTree
## Ferramenta: cria os canais de som do jogo em `res://default_bus_layout.tres` (o Godot usa esse
## arquivo sozinho, sem mexer no project.godot).
##   Godot --headless --path . -s res://tools/make_audio_buses.gd
##
## Master (volume geral das opções, com um limitador: vários tiros juntos não estouram)
##   Music  (música; volume próprio nas opções)
##   SFX    (tiros, passos, trilho, vento)
##   UI     (cliques e avisos da interface)

const OUT := "res://default_bus_layout.tres"


func _initialize() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)
	for bus_name: String in ["Music", "SFX", "UI"]:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	var err: Error = ResourceSaver.save(AudioServer.generate_bus_layout(), OUT)
	print("saved %s (%s): %d buses" % [OUT, error_string(err), AudioServer.bus_count])
	quit(0 if err == OK else 1)
