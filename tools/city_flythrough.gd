extends SceneTree
## Ferramenta de conferência: sobrevoo da cidade (sem personagens nem HUD), da tarde à noite, por
## um caminho de câmera suave que passa pela praça, pelas pontes e pelos dois quarteirões.
##   Godot --path . -s res://tools/city_flythrough.gd --resolution 1280x720 --always-on-top \
##       --write-movie <pasta>/voo.avi --fixed-fps 30
## Depois: ffmpeg -i <pasta>/voo.avi -c:v libx264 -pix_fmt yuv420p -an <pasta>/voo.mp4

const ARENA := "res://levels/skyplaza/skyplaza.tscn"
const SECONDS: float = 36.0
## Pontos do caminho: [posição da câmera, para onde olha]. Norte = -Z, leste = +X.
const PATH: Array = [
	[Vector3(0.0, 40.0, 95.0), Vector3(0.0, 0.0, 0.0)],
	[Vector3(0.0, 14.0, 40.0), Vector3(0.0, 4.0, 0.0)],
	[Vector3(0.0, 2.5, 18.0), Vector3(0.0, 4.0, -12.0)],
	[Vector3(6.0, 2.5, 4.0), Vector3(17.0, 6.0, -10.0)],
	[Vector3(16.0, 2.5, 0.0), Vector3(40.0, 3.0, 0.0)],
	[Vector3(32.0, 2.2, 0.0), Vector3(52.0, 3.5, -2.0)],
	[Vector3(38.0, 1.8, 6.0), Vector3(52.0, 3.5, -4.0)],
	[Vector3(40.0, 10.0, 22.0), Vector3(20.0, 4.0, 8.0)],
	[Vector3(12.0, 9.0, 26.0), Vector3(-12.0, 4.0, 0.0)],
	[Vector3(0.0, 4.0, 14.0), Vector3(-20.0, 3.0, 0.0)],
	[Vector3(-14.0, 2.5, 0.0), Vector3(-40.0, 3.0, 0.0)],
	[Vector3(-32.0, 2.3, 0.0), Vector3(-48.0, 4.0, -1.0)],
	[Vector3(-42.0, 2.3, -2.0), Vector3(-50.0, 5.0, 4.0)],
	[Vector3(-44.0, 2.6, -13.0), Vector3(-50.0, 5.0, 6.0)],
	[Vector3(-42.0, 16.0, -16.0), Vector3(-20.0, 2.0, 0.0)],
	[Vector3(-30.0, 20.0, 30.0), Vector3(-10.0, 2.0, 0.0)],
	[Vector3(10.0, 45.0, 90.0), Vector3(0.0, 0.0, 0.0)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	var level: Node3D = (load(ARENA) as PackedScene).instantiate()
	root.add_child(level)
	(level.get_node("Deathmatch") as Deathmatch).time_left = 3600.0
	for node: Node in get_nodes_in_group(&"characters"):
		var character := node as Character
		character.visible = false
		character.process_mode = Node.PROCESS_MODE_DISABLED
		for layer: Node in character.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	level.add_child(camera)
	camera.current = true
	var sky := level.find_child("SkyCycle", true, false) as SkyCycle
	var frames: int = roundi(SECONDS * 30.0)
	for frame in frames:
		var t: float = float(frame) / float(frames - 1)
		sky.forced_progress = lerpf(0.08, 0.92, smoothstep(0.1, 0.95, t))
		var at: Array = _sample(t)
		camera.global_position = at[0]
		camera.look_at(at[1], Vector3.UP)
		await process_frame
	quit()


# Posição e alvo no instante `t` (0 a 1), por uma curva Catmull-Rom pelos pontos do caminho.
func _sample(t: float) -> Array:
	var segments: int = PATH.size() - 1
	var x: float = clampf(t, 0.0, 1.0) * segments
	var i: int = mini(int(x), segments - 1)
	var f: float = smoothstep(0.0, 1.0, x - i) * 0.35 + (x - i) * 0.65
	var result: Array = []
	for k in 2:
		var p0: Vector3 = PATH[maxi(i - 1, 0)][k]
		var p1: Vector3 = PATH[i][k]
		var p2: Vector3 = PATH[i + 1][k]
		var p3: Vector3 = PATH[mini(i + 2, segments)][k]
		result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f))
	return result
