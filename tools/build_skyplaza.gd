extends SceneTree
## Ferramenta: monta a arena "Sky Plaza" a partir do mapa descrito aqui e salva duas cenas:
##   levels/skyplaza/skyplaza_geometry.tscn  chão, pontes, prédios, coberturas (tudo com colisão,
##                                           e é o que a navmesh lê)
##   levels/skyplaza/skyplaza_decor.tscn     árvores, arbustos, flores (só visual)
##   levels/skyplaza/skyplaza_rails.tscn     trilhos aéreos (fora da navmesh)
## Depois de rodar, recalcular a navmesh:
##   Godot --headless --path . -s res://tools/build_skyplaza.gd
##   Godot --headless --path . -s res://tools/bake_navmesh.gd -- res://levels/skyplaza/skyplaza.tscn res://levels/skyplaza/skyplaza_navmesh.tres
##
## Coordenadas em metros. Praça no centro (topo em y = 0), ilha oeste mais alta (y = 1),
## ilha leste mais baixa (y = -1), pontes ligando as três.

const CITY := "res://assets/models/city/downtown/"
const NATURE := "res://assets/models/nature/stylized/"
const OUT_DIR := "res://levels/skyplaza/"

const PLAZA := {"center": Vector3(0, 0, 0), "radius": 20.0}
const WEST := {"center": Vector3(-42, 1, 0), "radius": 14.0}
const EAST := {"center": Vector3(42, -1, 0), "radius": 14.0}

var _geometry: Node3D
var _decor: Node3D
var _rails: Node3D
var _shape_cache: Dictionary = {}
var _materials: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_make_materials()
	_geometry = Node3D.new()
	_geometry.name = "SkyPlazaGeometry"
	root.add_child(_geometry)
	_decor = Node3D.new()
	_decor.name = "SkyPlazaDecor"
	root.add_child(_decor)

	_build_island("Plaza", PLAZA)
	_build_island("West", WEST)
	_build_island("East", EAST)
	# Das bordas da praça (raio 20) até as bordas das ilhas laterais (raio 14).
	_build_bridge("BridgeWest", Vector3(-20.0, 0.0, 0.0), Vector3(-28.0, 1.0, 0.0))
	_build_bridge("BridgeEast", Vector3(20.0, 0.0, 0.0), Vector3(28.0, -1.0, 0.0))
	_build_plaza()
	_build_west_garden()
	_build_east_courtyard()

	_build_rails()

	_save(_geometry, OUT_DIR + "skyplaza_geometry.tscn")
	_save(_decor, OUT_DIR + "skyplaza_decor.tscn")
	_save(_rails, OUT_DIR + "skyplaza_rails.tscn")
	quit()


# ---------------------------------------------------------------- áreas

func _build_plaza() -> void:
	var city := _group(_geometry, "PlazaCity")
	# Piso de mármore 24 x 24 m (1 cm acima da grama, sem colisão própria: pisa-se na ilha).
	for ix in 6:
		for iz in 6:
			_place(city, CITY + "Floor_4x4.gltf", Vector3(-10 + ix * 4, 0.01, -10 + iz * 4), 0.0, "none")
	# Anel de 4 muros de concreto (2 blocos lado a lado, 2 de altura) a 7 m do centro.
	for side: Vector3 in [Vector3(7, 0, 0), Vector3(-7, 0, 0), Vector3(0, 0, 7), Vector3(0, 0, -7)]:
		var along: Vector3 = Vector3(0, 0, 1) if side.x != 0.0 else Vector3(1, 0, 0)
		for offset: float in [-1.0, 1.0]:
			for level: int in 2:
				_place(city, CITY + "Entrance_Concrete_2x2.gltf", side + along * offset + Vector3.UP * level, 0.0, "box")
	# Jardineira central com a árvore-marco.
	_place(city, CITY + "Prop_Planter_Single.gltf", Vector3(0, 0, 0), 0.0, "box")
	_tree(Vector3(0, 0.55, 0), NATURE + "CommonTree_3.gltf", 0.0)
	# Cantos da praça: jardineiras com arbustos e aparelhos de ar-condicionado (cobertura baixa).
	for corner: Vector3 in [Vector3(12, 0, 12), Vector3(-12, 0, 12), Vector3(12, 0, -12), Vector3(-12, 0, -12)]:
		_place(city, CITY + "Prop_Planter_Single.gltf", corner, 0.0, "box")
		_place(_decor, NATURE + "Bush_Common_Flowers.gltf", corner + Vector3(0, 0.55, 0), 0.0, "none")
		_place(city, CITY + "Prop_ACUnit.gltf", corner * 0.72 + Vector3(0, 0, 0), 45.0, "box")
	# Balizadores marcando as saídas das pontes.
	for x: float in [-16.5, 16.5]:
		for z: float in [-2.2, 2.2]:
			_place(city, CITY + "Prop_Bollard.gltf", Vector3(x, 0, z), 0.0, "box")
	# Grama nas bordas.
	for i in 18:
		var angle: float = i * TAU / 18.0 + 0.17
		_place(_decor, NATURE + "Grass_Common_Short.gltf", Vector3(cos(angle), 0, sin(angle)) * 17.5, i * 40.0, "none")


func _build_west_garden() -> void:
	var c: Vector3 = WEST["center"]
	var garden := _group(_geometry, "WestGarden")
	# Rochas grandes são a cobertura principal do jardim.
	for rock: Array in [[Vector3(6, 0, -4), "Rock_Medium_1", 20.0], [Vector3(-2, 0, 1), "Rock_Medium_3", 110.0],
			[Vector3(4, 0, 6), "Rock_Medium_2", 200.0], [Vector3(-7, 0, -3), "Rock_Medium_1", 300.0],
			[Vector3(-3, 0, 8), "Rock_Medium_2", 60.0]]:
		_place(garden, NATURE + rock[1] + ".gltf", c + rock[0], rock[2], "convex")
	_tree(c + Vector3(-5, 0, -8), NATURE + "CommonTree_1.gltf", 30.0)
	_tree(c + Vector3(2, 0, 9), NATURE + "CommonTree_1.gltf", 160.0)
	_tree(c + Vector3(-8, 0, 5), NATURE + "TwistedTree_1.gltf", 80.0)
	for spot: Vector3 in [Vector3(8, 0, 2), Vector3(-1, 0, -7), Vector3(-9, 0, 0), Vector3(1, 0, 4)]:
		_place(_decor, NATURE + "Bush_Common.gltf", c + spot, spot.x * 20.0, "none")
	for spot: Vector3 in [Vector3(3, 0, -9), Vector3(-6, 0, 9), Vector3(9, 0, -6), Vector3(-10, 0, -6)]:
		_place(_decor, NATURE + "Flower_3_Group.gltf", c + spot, spot.z * 15.0, "none")
		_place(_decor, NATURE + "Fern_1.gltf", c + spot + Vector3(1.5, 0, 0.5), spot.x * 25.0, "none")


func _build_east_courtyard() -> void:
	var c: Vector3 = EAST["center"]
	var court := _group(_geometry, "EastCourtyard")
	# Prédio pequeno ocupando a metade leste da ilha (origem do modelo fica numa quina).
	_place(court, CITY + "Building_Small_1.gltf", c + Vector3(3.2, 0, 5.0), 0.0, "box")
	# Pátio na frente do prédio: calçada rente ao chão (1 cm acima; o personagem não sobe degrau),
	# muros de concreto e objetos de rua.
	for iz in 5:
		for ix in 3:
			_place(court, CITY + "Sidewalk_Straight_3m.gltf", c + Vector3(-9 + ix * 3, 0.01, -6 + iz * 3), 0.0, "none")
	for spot: Vector3 in [Vector3(-6, 0, -4), Vector3(-6, 0, 4)]:
		for offset: float in [-1.0, 1.0]:
			_place(court, CITY + "Entrance_Concrete_2x2.gltf", c + spot + Vector3(0, 0, offset), 0.0, "box")
	_place(court, CITY + "Entrance_Concrete_2x2.gltf", c + Vector3(-2, 0, 0), 0.0, "box")
	_place(court, CITY + "Entrance_Concrete_2x2.gltf", c + Vector3(-2, 1, 0), 0.0, "box")
	for spot: Vector3 in [Vector3(-9, 0, -8), Vector3(-9, 0, 8), Vector3(-3, 0, -9), Vector3(-3, 0, 9)]:
		_place(court, CITY + "Prop_ACUnit.gltf", c + spot, spot.z * 10.0, "box")
		_place(court, CITY + "Prop_Bollard.gltf", c + spot + Vector3(1.2, 0, 0), 0.0, "box")


# Dois trilhos (norte e sul) do jardim ao pátio passando por cima da borda da praça. As pontas
# ficam sobre as ilhas laterais, uns 7 m para dentro da borda (ao chegar no fim, o personagem
# cai no chão, freado e ainda andando um pouco para frente).
func _build_rails() -> void:
	_rails = Node3D.new()
	_rails.name = "SkyPlazaRails"
	root.add_child(_rails)
	var rail_script: Script = load("res://rails/skyline_rail.gd")
	for side: float in [-1.0, 1.0]:
		var points: Array[Vector3] = [Vector3(-35, 7.5, 7), Vector3(-27, 8.5, 13), Vector3(-14, 9.5, 17),
				Vector3(0, 10, 18), Vector3(14, 9.5, 17), Vector3(26, 8.5, 13), Vector3(35, 7, 8)]
		var curve := Curve3D.new()
		for i in points.size():
			var point: Vector3 = points[i] * Vector3(1, 1, side)
			var previous: Vector3 = points[maxi(i - 1, 0)] * Vector3(1, 1, side)
			var next: Vector3 = points[mini(i + 1, points.size() - 1)] * Vector3(1, 1, side)
			# Alças em volta de cada ponto deixam a curva suave (estilo Catmull-Rom).
			var handle: Vector3 = (next - previous) * 0.2
			curve.add_point(point, -handle, handle)
		var rail := Path3D.new()
		rail.name = "RailNorth" if side < 0.0 else "RailSouth"
		rail.curve = curve
		rail.set_script(rail_script)
		rail.set(&"tube_material", _materials["brass"])
		rail.set(&"pylon_material", _materials["iron"])
		_rails.add_child(rail)
		rail.owner = _rails


# ---------------------------------------------------------------- blocos de construção

func _build_island(island_name: String, island: Dictionary) -> void:
	var combiner := CSGCombiner3D.new()
	combiner.name = island_name + "Island"
	combiner.use_collision = true
	combiner.position = island["center"]
	_geometry.add_child(combiner)
	combiner.owner = _geometry
	var radius: float = island["radius"]
	var top := CSGCylinder3D.new()
	top.name = "Top"
	top.radius = radius
	top.height = 1.5
	top.sides = 40
	top.position = Vector3(0, -0.75, 0)
	top.material = _materials["grass"]
	combiner.add_child(top)
	top.owner = _geometry
	var underside := CSGCylinder3D.new()
	underside.name = "Underside"
	underside.radius = radius - 0.5
	underside.height = radius * 0.7
	underside.cone = true
	underside.sides = 14
	underside.smooth_faces = false
	# Cone de ponta para baixo: o topo do cone fica 0,2 m dentro do disco de grama.
	underside.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -1.3 - radius * 0.35, 0))
	underside.material = _materials["rock"]
	combiner.add_child(underside)
	underside.owner = _geometry
	# Rochas enfeitando a parte de baixo da borda (só visual: ficam abaixo do chão, onde
	# ninguém anda, para não parecerem obstáculos que dá para atravessar).
	for i in 7:
		var angle: float = i * TAU / 7.0 + radius
		var spot: Vector3 = island["center"] + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5) + Vector3(0, -4.0, 0)
		_place(_decor, NATURE + ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"][i % 3] + ".gltf", spot, i * 50.0, "none", 1.6)


# Ponte: perfil de mármore extrudado. Patamares planos de 1 m entram em cada ilha na altura do
# chão dela (1 cm abaixo, para as superfícies não piscarem) e a rampa fica só no vão: o personagem
# não sobe degrau, então as pontas não podem ter "quina". `from` e `to` são as bordas das ilhas.
func _build_bridge(bridge_name: String, from: Vector3, to: Vector3) -> void:
	const WIDTH := 3.2
	const THICKNESS := 0.4
	const LANDING := 1.0
	var flat: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length: float = flat.length()
	var forward: Vector3 = flat / length
	var rise: float = to.y - from.y
	var deck := CSGPolygon3D.new()
	deck.name = bridge_name
	deck.use_collision = true
	deck.depth = WIDTH
	deck.polygon = PackedVector2Array([
		Vector2(-LANDING, -THICKNESS), Vector2(-LANDING, -0.01), Vector2(0.0, -0.01),
		Vector2(length, rise - 0.01), Vector2(length + LANDING, rise - 0.01),
		Vector2(length + LANDING, rise - THICKNESS), Vector2(length, rise - THICKNESS), Vector2(0.0, -THICKNESS),
	])
	deck.material = _materials["bridge"]
	# X local ao longo da ponte, Y para cima; a extrusão vai para -Z local (centralizada).
	var side: Vector3 = forward.cross(Vector3.UP)
	deck.transform = Transform3D(Basis(forward, Vector3.UP, side), from + side * (WIDTH * 0.5))
	_geometry.add_child(deck)
	deck.owner = _geometry
	# Guarda-corpo: peças de 2 m nas duas bordas do vão (colisão de 1 m: dá para pular por cima).
	var segments: int = maxi(int(length / 2.0), 1)
	for offset: float in [-1.6, 1.6]:
		for i in segments:
			var t: float = (i + 0.5) / segments
			var at: Vector3 = from.lerp(to, t) + side * offset
			_place(_geometry, CITY + "Trim_Wall_Guard.gltf", at, rad_to_deg(atan2(forward.x, forward.z)) + 90.0, "railing")


func _tree(at: Vector3, path: String, rotation_degrees: float) -> void:
	_place(_decor, path, at, rotation_degrees, "none")
	# Só o tronco colide (e entra na navmesh como obstáculo); a copa é só visual.
	var body := StaticBody3D.new()
	body.name = "Trunk_%d_%d" % [roundi(at.x), roundi(at.z)]
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.45
	cylinder.height = 4.0
	shape.shape = cylinder
	shape.position = Vector3(0, 2.0, 0)
	body.add_child(shape)
	body.position = at
	_geometry.add_child(body)
	body.owner = _geometry
	shape.owner = _geometry


func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	node.owner = parent if parent == _geometry or parent == _decor else parent.owner
	return node


## Coloca uma peça (cena glTF) e cria a colisão: "none", "box" (caixa do tamanho da peça),
## "convex" (forma da peça simplificada) ou "railing" (caixa de 1 m de altura).
func _place(parent: Node3D, path: String, at: Vector3, rotation_degrees: float, collision: String, scale: float = 1.0) -> Node3D:
	var scene: PackedScene = load(path)
	var piece: Node3D = scene.instantiate()
	piece.position = at
	piece.rotation_degrees.y = rotation_degrees
	piece.scale = Vector3.ONE * scale
	parent.add_child(piece)
	var scene_root: Node = _geometry if parent == _geometry or parent.owner == _geometry else _decor
	piece.owner = scene_root
	if collision == "none":
		return piece
	var body := StaticBody3D.new()
	body.name = "Collision"
	piece.add_child(body)
	body.owner = scene_root
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var shape := CollisionShape3D.new()
		# Posição da malha no espaço da peça (vale mesmo se o glTF tiver nós aninhados).
		var relative: Transform3D = piece.global_transform.affine_inverse() * mesh_instance.global_transform
		var local_box: AABB = relative * mesh_instance.get_aabb()
		match collision:
			"box":
				var box := BoxShape3D.new()
				box.size = local_box.size.max(Vector3.ONE * 0.1)
				shape.shape = box
				shape.position = local_box.get_center()
			"railing":
				var rail := BoxShape3D.new()
				rail.size = Vector3(local_box.size.x, 1.0, 0.2)
				shape.shape = rail
				shape.position = local_box.get_center() + Vector3(0, 0.5 - local_box.size.y * 0.5, 0)
			"convex":
				if not _shape_cache.has(mesh_instance.mesh):
					_shape_cache[mesh_instance.mesh] = mesh_instance.mesh.create_convex_shape(true, true)
				shape.shape = _shape_cache[mesh_instance.mesh]
				shape.transform = relative
		body.add_child(shape)
		shape.owner = scene_root
	return piece


func _make_materials() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.42, 0.62, 0.3)
	_materials["grass"] = grass
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.52, 0.46, 0.4)
	_materials["rock"] = rock
	var bridge := StandardMaterial3D.new()
	bridge.albedo_texture = load(CITY + "T_MarbleFloor_BaseColor.png")
	bridge.uv1_triplanar = true
	bridge.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_materials["bridge"] = bridge
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.66, 0.3)
	brass.metallic = 0.75
	brass.roughness = 0.35
	_materials["brass"] = brass
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.19, 0.2)
	iron.metallic = 0.5
	iron.roughness = 0.6
	_materials["iron"] = iron


func _save(scene_root: Node, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := PackedScene.new()
	var err: Error = packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved %s (%s): %d nodes" % [path, error_string(err), scene_root.find_children("*", "", true, false).size()])
