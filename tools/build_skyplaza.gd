extends SceneTree
## Ferramenta: monta a arena "Sky Plaza" (quarteirões de cidade flutuantes, começo do século XX)
## a partir do mapa descrito aqui e salva as cenas:
##   levels/skyplaza/skyplaza_geometry.tscn  plataformas, pontes, prédios, coberturas (tudo com
##                                           colisão; é o que a navmesh lê)
##   levels/skyplaza/skyplaza_decor.tscn     árvores, arbustos, flores, rochas (só visual)
##   levels/skyplaza/skyplaza_rails.tscn     trilhos aéreos (fora da navmesh)
##   levels/skyplaza/skyplaza_clouds.tscn    mar de nuvens em volta (só visual)
##   levels/skyplaza/meshes/*.res            prédios e enfeites já juntados (CityKit)
## Depois de rodar, recalcular a navmesh:
##   Godot --headless --path . -s res://tools/build_skyplaza.gd
##   Godot --headless --path . -s res://tools/bake_navmesh.gd -- res://levels/skyplaza/skyplaza.tscn res://levels/skyplaza/skyplaza_navmesh.tres
##
## Coordenadas em metros. Três quarteirões:
##   Praça (centro, topo y = 0): 44 x 44 m, prédios nos 4 cantos formam uma cruz aberta (a praça
##     no meio e 4 "braços"); os braços leste/oeste levam às pontes, os norte/sul terminam num
##     balaústre sobre o céu, onde os trilhos passam por cima ("estações").
##   Oeste (y = 1): residencial. Fileira de casas de tijolo na borda de fora, rua e um parque.
##   Leste (y = -1): comercial. Lojas com vitrines na borda de fora e um largo de feira.
## Norte = -Z (a "frente" do Godot), leste = +X. Nada pode ter degrau: os pisos são planos 1 cm acima da plataforma (só visual).

const CITY := "res://assets/models/city/downtown/"
const NATURE := "res://assets/models/nature/stylized/"
## Texturas de chão pintadas à mão (Stylized Grass & Dirt, JulioVII, CC-BY: ver CREDITS.md).
const GROUND := "res://assets/textures/juliovii/"
## Tufos de capim e flores soltas espalhados pelo gramado: [modelo, quantos a cada m², escala mín., máx.].
## O "capim curto" do Nature Kit tem 1,3 m de altura: aqui fica entre 45 e 65 cm.
const LAWN_PLANTS: Array = [
	["Grass_Common_Short", 0.55, 0.35, 0.5],
	["Grass_Common_Tall", 0.12, 0.35, 0.45],
	["Flower_3_Single", 0.05, 0.35, 0.45],
]
## O capim some a partir desta distância da câmera (é só enfeite: de longe a textura basta).
const LAWN_VISIBLE_RANGE: float = 40.0
const OUT_DIR := "res://levels/skyplaza/"
const MESH_DIR := "res://levels/skyplaza/meshes/"

## Quarteirões: centro do topo e tamanho (x, z).
const PLAZA := {"center": Vector3(0, 0, 0), "size": Vector2(44, 44)}
const WEST := {"center": Vector3(-44, 1, 0), "size": Vector2(28, 32)}
const EAST := {"center": Vector3(44, -1, 0), "size": Vector2(28, 32)}
## Meia largura dos braços da cruz da praça (os prédios começam aqui).
const ARM_HALF: float = 10.0

var _geometry: Node3D
var _decor: Node3D
var _rails: Node3D
var _clouds: Node3D
var _kit := CityKit.new()
var _items: Node3D
var _shape_cache: Dictionary = {}
var _materials: Dictionary = {}
var _lamp_globes: Array[Vector3] = []
## Pisos para o som dos passos: [tipo, centro, tamanho] (ver levels/floor_surfaces.gd).
var _surfaces: Array = []


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

	_build_block("Plaza", PLAZA)
	_build_block("West", WEST)
	_build_block("East", EAST)
	# Das bordas da praça (x = ±22) até as bordas dos quarteirões laterais (x = ±30).
	_build_bridge("BridgeWest", Vector3(-22.0, 0.0, 0.0), Vector3(-30.0, 1.0, 0.0))
	_build_bridge("BridgeEast", Vector3(22.0, 0.0, 0.0), Vector3(30.0, -1.0, 0.0))
	_build_plaza()
	_build_west_quarter()
	_build_east_quarter()
	_build_lamp_globes()

	_build_rails()
	_build_items()
	_build_clouds()

	_geometry.set_meta(FloorSurfaces.META, _surfaces)
	_geometry.add_to_group(FloorSurfaces.GROUP, true)
	_save(_geometry, OUT_DIR + "skyplaza_geometry.tscn")
	_save(_decor, OUT_DIR + "skyplaza_decor.tscn")
	_save(_rails, OUT_DIR + "skyplaza_rails.tscn")
	_save(_items, OUT_DIR + "skyplaza_items.tscn")
	_save(_clouds, OUT_DIR + "skyplaza_clouds.tscn")
	print("city pieces: ", _kit.piece_count)
	quit()


# ---------------------------------------------------------------- áreas

func _build_plaza() -> void:
	var city := _group(_geometry, "PlazaCity")
	var arm: float = ARM_HALF
	var edge: float = PLAZA["size"].x * 0.5
	# Pisos: mármore na praça, rua de asfalto nos braços, calçada junto aos prédios.
	_floor(city, "marble", Vector3.ZERO, Vector2(arm * 2.0, arm * 2.0))
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var along_x: bool = direction.x == 0.0
		var middle: Vector3 = direction * (arm + edge) * 0.5
		var arm_size := Vector2(arm * 2.0 - 6.0, edge - arm) if along_x else Vector2(edge - arm, arm * 2.0 - 6.0)
		_floor(city, "asphalt", middle, arm_size)
		for sidewalk: float in [-1.0, 1.0]:
			var offset: Vector3 = (Vector3.RIGHT if along_x else Vector3.BACK) * sidewalk * (arm - 1.5)
			_floor(city, "sidewalk", middle + offset, Vector2(3.0, edge - arm) if along_x else Vector2(edge - arm, 3.0))

	# Prédios dos 4 cantos (12 x 12 m). Lados detalhados = os que dão para a cruz.
	# Lados: 0 = +Z (sul), 1 = +X (leste), 2 = -Z (norte), 3 = -X (oeste).
	var corner: float = arm + 6.0
	_building(city, "PlazaSE", Vector3(corner, 0, corner), 0.0, {"width": 6, "depth": 6, "floors": 3,
			"style": "civic", "roof": "mansard", "detailed": [false, false, true, true], "door_side": 3})
	_building(city, "PlazaSW", Vector3(-corner, 0, corner), 0.0, {"width": 6, "depth": 6, "floors": 3,
			"style": "brick", "roof": "mansard", "detailed": [false, true, true, false], "door_side": 1})
	_building(city, "PlazaNE", Vector3(corner, 0, -corner), 0.0, {"width": 6, "depth": 6, "floors": 3,
			"style": "shop", "roof": "flat", "detailed": [true, false, false, true], "door_side": 0})
	_building(city, "PlazaNW", Vector3(-corner, 0, -corner), 0.0, {"width": 6, "depth": 6, "floors": 2,
			"style": "brick", "roof": "mansard", "detailed": [true, true, false, false], "door_side": 0})

	# Anel de 4 muros de concreto (2 blocos lado a lado, 2 de altura) a 7 m do centro.
	for side: Vector3 in [Vector3(7, 0, 0), Vector3(-7, 0, 0), Vector3(0, 0, 7), Vector3(0, 0, -7)]:
		var along: Vector3 = Vector3(0, 0, 1) if side.x != 0.0 else Vector3(1, 0, 0)
		for offset: float in [-1.0, 1.0]:
			for level: int in 2:
				_place(city, CITY + "Entrance_Concrete_2x2.gltf", side + along * offset + Vector3.UP * level, 0.0, "box")
	# Jardineira central com a árvore-marco; jardineiras com arbustos nas quinas da praça.
	_place(city, CITY + "Prop_Planter_Single.gltf", Vector3.ZERO, 0.0, "box")
	_tree(Vector3(0, 0.55, 0), NATURE + "CommonTree_3.gltf", 0.0)
	for quina: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_place(city, CITY + "Prop_Planter_Single.gltf", quina * (arm - 2.0), 0.0, "box")
		_place(_decor, NATURE + "Bush_Common_Flowers.gltf", quina * (arm - 2.0) + Vector3(0, 0.55, 0), 0.0, "none")
		_lamp(quina * (arm - 0.6))
	# Postes nas calçadas dos braços.
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var along_x: bool = direction.x == 0.0
		for sidewalk: float in [-1.0, 1.0]:
			var offset: Vector3 = (Vector3.RIGHT if along_x else Vector3.BACK) * sidewalk * (arm - 0.6)
			_lamp(direction * (arm + 6.0) + offset)
	# Balaústres nas pontas dos braços (colisão de 1 m: dá para pular por cima); os braços
	# leste e oeste têm a abertura da ponte no meio.
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var bridge_gap: bool = direction.x != 0.0
		for i in int(arm):
			var u: float = -arm + 1.0 + i * 2.0
			if bridge_gap and absf(u) < 2.0:
				continue
			var along: Vector3 = Vector3.RIGHT if direction.x == 0.0 else Vector3.BACK
			_balustrade(city, direction * (edge - 0.2) + along * u, along)
	# Balizadores de ferro marcando as saídas das pontes.
	for x: float in [-edge + 1.5, edge - 1.5]:
		for z: float in [-2.2, 2.2]:
			_place(city, CITY + "Prop_Bollard.gltf", Vector3(x, 0, z), 0.0, "box")
	_commit_props(city, "PlazaProps")


func _build_west_quarter() -> void:
	var c: Vector3 = WEST["center"]
	var half: Vector2 = WEST["size"] * 0.5
	var quarter := _group(_geometry, "WestQuarter")
	# Fileira de casas na borda de fora (x de -58 a -48), de frente para o leste (+X).
	var row_x: float = c.x - half.x + 5.0
	var houses: Array = [
		[-11.0, {"width": 5, "depth": 5, "floors": 3, "style": "brick", "roof": "mansard"}],
		[0.0, {"width": 6, "depth": 5, "floors": 4, "style": "civic", "roof": "flat"}],
		[11.0, {"width": 5, "depth": 5, "floors": 3, "style": "brick", "roof": "mansard"}],
	]
	for i in houses.size():
		var spec: Dictionary = houses[i][1]
		# Virada +90°: frente (lado 0) para +X (leste); lado 1 para -Z, lado 3 para +Z, fundos para o céu.
		spec["detailed"] = [true, i == 0, false, i == houses.size() - 1]
		spec["door_side"] = 0
		_building(quarter, "WestHouse%d" % (i + 1), Vector3(row_x, c.y, c.z + houses[i][0]), PI * 0.5, spec)
	# Calçada junto às casas, rua e parque (grama) perto da ponte, com um caminho até a rua.
	var street_x: float = row_x + 5.0
	_floor(quarter, "sidewalk", Vector3(street_x + 1.5, c.y, c.z), Vector2(3.0, half.y * 2.0))
	_floor(quarter, "asphalt", Vector3(street_x + 6.5, c.y, c.z), Vector2(7.0, half.y * 2.0))
	var park_x0: float = street_x + 10.0
	var park_x1: float = c.x + half.x
	_floor(quarter, "grass", Vector3((park_x0 + park_x1) * 0.5, c.y, c.z), Vector2(park_x1 - park_x0, half.y * 2.0))
	_floor(quarter, "sidewalk", Vector3((park_x0 + park_x1) * 0.5, c.y + 0.005, c.z), Vector2(park_x1 - park_x0, 3.0))
	# Parque: rochas grandes são a cobertura; árvores e canteiros.
	var park_c := Vector3((park_x0 + park_x1) * 0.5, c.y, c.z)
	for rock: Array in [[Vector3(-1, 0, -6), "Rock_Medium_1", 20.0], [Vector3(2, 0, 7), "Rock_Medium_2", 200.0],
			[Vector3(-3, 0, 11), "Rock_Medium_3", 110.0], [Vector3(3, 0, -11), "Rock_Medium_2", 60.0]]:
		_place(quarter, NATURE + rock[1] + ".gltf", park_c + rock[0], rock[2], "convex")
	# Árvores longe do caminho dos trilhos (que vêm de x = -36, z = ±7 para o nordeste/sudeste).
	_tree(park_c + Vector3(1.5, 0, -3.5), NATURE + "CommonTree_1.gltf", 30.0)
	_tree(park_c + Vector3(-3, 0, 3), NATURE + "CommonTree_1.gltf", 160.0)
	_tree(park_c + Vector3(-3.5, 0, 13), NATURE + "TwistedTree_1.gltf", 80.0)
	for spot: Vector3 in [Vector3(-3, 0, -3), Vector3(3, 0, 3), Vector3(-2, 0, -13), Vector3(3, 0, 10)]:
		_place(_decor, NATURE + "Bush_Common.gltf", park_c + spot, spot.x * 20.0, "none")
	for spot: Vector3 in [Vector3(2, 0, -8), Vector3(-3, 0, 8), Vector3(0, 0, -14), Vector3(-1, 0, 14)]:
		_place(_decor, NATURE + "Flower_3_Group.gltf", park_c + spot, spot.z * 15.0, "none")
		_place(_decor, NATURE + "Fern_1.gltf", park_c + spot + Vector3(1.2, 0, 0.5), spot.x * 25.0, "none")
	for z: float in [-12.0, -4.0, 4.0, 12.0]:
		_lamp(Vector3(street_x + 0.6, c.y, c.z + z))
	_commit_props(quarter, "WestProps")
	# Capim e flores soltas no gramado, longe do caminho, das pedras, das árvores e dos canteiros.
	var avoid: Array = [
		[park_c + Vector3(-1, 0, -6), 1.8], [park_c + Vector3(2, 0, 7), 1.8], [park_c + Vector3(-3, 0, 11), 1.8],
		[park_c + Vector3(3, 0, -11), 1.8], [park_c + Vector3(1.5, 0, -3.5), 1.1], [park_c + Vector3(-3, 0, 3), 1.1],
		[park_c + Vector3(-3.5, 0, 13), 1.1]]
	for spot: Vector3 in [Vector3(-3, 0, -3), Vector3(3, 0, 3), Vector3(-2, 0, -13), Vector3(3, 0, 10)]:
		avoid.append([park_c + spot, 1.0])
	for spot: Vector3 in [Vector3(2, 0, -8), Vector3(-3, 0, 8), Vector3(0, 0, -14), Vector3(-1, 0, 14)]:
		avoid.append([park_c + spot, 0.9])
		avoid.append([park_c + spot + Vector3(1.2, 0, 0.5), 0.8])
	var lawn := Rect2(Vector2(park_x0, c.z - half.y), Vector2(park_x1 - park_x0, half.y * 2.0))
	_lawn_plants(lawn, c.y + 0.01, [Rect2(Vector2(park_x0, c.z - 1.9), Vector2(park_x1 - park_x0, 3.8))], avoid)


func _build_east_quarter() -> void:
	var c: Vector3 = EAST["center"]
	var half: Vector2 = EAST["size"] * 0.5
	var quarter := _group(_geometry, "EastQuarter")
	# Lojas na borda de fora (x de 48 a 58), de frente para o oeste (-X).
	var row_x: float = c.x + half.x - 5.0
	var shops: Array = [
		[-11.0, {"width": 5, "depth": 5, "floors": 2, "style": "shop", "roof": "flat"}],
		[0.0, {"width": 6, "depth": 5, "floors": 3, "style": "shop", "roof": "mansard"}],
		[11.0, {"width": 5, "depth": 5, "floors": 2, "style": "civic", "roof": "flat"}],
	]
	for i in shops.size():
		var spec: Dictionary = shops[i][1]
		# Virada -90°: frente (lado 0) para -X; lado 1 para +Z, lado 3 para -Z.
		spec["detailed"] = [true, i == shops.size() - 1, false, i == 0]
		spec["door_side"] = 0
		_building(quarter, "EastShop%d" % (i + 1), Vector3(row_x, c.y, c.z + shops[i][0]), -PI * 0.5, spec)
	# Calçada das lojas e largo de feira calçado.
	var front_x: float = row_x - 5.0
	_floor(quarter, "sidewalk", Vector3(front_x - 1.5, c.y, c.z), Vector2(3.0, half.y * 2.0))
	var square_x0: float = c.x - half.x
	var square_x1: float = front_x - 3.0
	_floor(quarter, "marble", Vector3((square_x0 + square_x1) * 0.5, c.y, c.z), Vector2(square_x1 - square_x0, half.y * 2.0))
	# Coberturas do largo: dois muros de concreto e um bloco duplo no meio, jardineiras.
	for spot: Vector3 in [Vector3(-8, 0, -4), Vector3(-8, 0, 4)]:
		for offset: float in [-1.0, 1.0]:
			_place(quarter, CITY + "Entrance_Concrete_2x2.gltf", c + spot + Vector3(0, 0, offset), 0.0, "box")
	_place(quarter, CITY + "Entrance_Concrete_2x2.gltf", c + Vector3(-3, 0, 0), 0.0, "box")
	_place(quarter, CITY + "Entrance_Concrete_2x2.gltf", c + Vector3(-3, 1, 0), 0.0, "box")
	for spot: Vector3 in [Vector3(-11, 0, -12), Vector3(-11, 0, 12), Vector3(-2, 0, -10), Vector3(-2, 0, 10)]:
		_place(quarter, CITY + "Prop_Planter_Single.gltf", c + spot, 0.0, "box")
		_place(_decor, NATURE + "Bush_Common_Flowers.gltf", c + spot + Vector3(0, 0.55, 0), 0.0, "none")
	for z: float in [-12.0, -4.0, 4.0, 12.0]:
		_lamp(Vector3(front_x - 0.6, c.y, c.z + z))
	_commit_props(quarter, "EastProps")


# Dois trilhos (norte e sul) do parque oeste ao largo leste. Eles saem por fora dos prédios da
# praça (sobre o céu) e passam por cima da ponta dos braços norte/sul (a "estação", onde dá para
# engatar do chão e soltar em cima do braço). As pontas ficam ~7 m para dentro dos quarteirões.
func _build_rails() -> void:
	_rails = Node3D.new()
	_rails.name = "SkyPlazaRails"
	root.add_child(_rails)
	var rail_script: Script = load("res://rails/skyline_rail.gd")
	for side: float in [-1.0, 1.0]:
		var points: Array[Vector3] = [Vector3(-36, 7.5, 7), Vector3(-31, 8.5, 17), Vector3(-20, 9.5, 27.5),
				Vector3(-11, 9.8, 24.5), Vector3(-5, 10, 21), Vector3(0, 10, 20.8), Vector3(5, 10, 21),
				Vector3(11, 9.8, 24.5), Vector3(20, 9.5, 27.5), Vector3(31, 8.5, 17), Vector3(36, 7, 8)]
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


# Itens: frascos de vida nos dois vãos diagonais da praça (disputados), no parque oeste e na
# entrada do largo leste. Todos em pontos abertos da navmesh.
func _build_items() -> void:
	_items = Node3D.new()
	_items.name = "SkyPlazaItems"
	root.add_child(_items)
	var health_spots: Array[Vector3] = [Vector3(5, 0, -5), Vector3(-5, 0, 5),
			Vector3(-34, 1, -10), Vector3(37, -1, 0)]
	for i in health_spots.size():
		_pickup("Health%d" % (i + 1), 0, health_spots[i], 20.0)  # 0 = Pickup.Kind.HEALTH
	# As armas ficam nas ruas dos braços leste e oeste, no caminho das pontes e longe dos
	# pontos de nascimento (ninguém nasce com uma arma melhor no colo).
	_pickup("Rifle", 2, Vector3(15, 0, -6), 30.0)  # 2 = Pickup.Kind.RIFLE
	_pickup("Shotgun", 3, Vector3(-15, 0, 6), 30.0)  # 3 = Pickup.Kind.SHOTGUN


func _pickup(item_name: String, kind: int, position: Vector3, respawn_time: float) -> void:
	var item: Node3D = load("res://items/pickup.tscn").instantiate()
	item.name = item_name
	item.set(&"kind", kind)
	item.set(&"respawn_time", respawn_time)
	item.position = position
	_items.add_child(item)
	item.owner = _items


# Mar de nuvens: cada nuvem é um aglomerado de esferas achatadas (opacas, baratas no celular),
# tudo junto numa malha só, sem sombra e sem colisão. A maioria fica abaixo dos quarteirões, para
# a cidade parecer flutuar sobre as nuvens; algumas passam mais alto, ao longe.
func _build_clouds() -> void:
	const COUNT := 70
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260922
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 8
	puff.rings = 4
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in COUNT:
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(58.0, 180.0)
		var height: float = rng.randf_range(-30.0, -7.0) if rng.randf() < 0.75 else rng.randf_range(14.0, 36.0)
		var center := Vector3(cos(angle) * distance, height, sin(angle) * distance * 0.85)
		var size: float = rng.randf_range(0.8, 1.9)
		for p in rng.randi_range(4, 8):
			var offset := Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-1.2, 1.2), rng.randf_range(-5.0, 5.0)) * size
			var radius: float = rng.randf_range(3.5, 7.0) * size
			var shape := Basis.from_scale(Vector3(radius, radius * rng.randf_range(0.35, 0.55), radius))
			tool.append_from(puff, 0, Transform3D(shape, center + offset))
	_clouds = Node3D.new()
	_clouds.name = "SkyPlazaClouds"
	root.add_child(_clouds)
	var instance := MeshInstance3D.new()
	instance.name = "Clouds"
	instance.mesh = tool.commit()
	instance.material_override = _materials["cloud"]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.add_child(instance)
	instance.owner = _clouds


# ---------------------------------------------------------------- blocos de construção

# Plataforma flutuante: laje de pedra com a base em pirâmide de rocha e pedras penduradas.
func _build_block(block_name: String, block: Dictionary) -> void:
	var size: Vector2 = block["size"]
	var combiner := CSGCombiner3D.new()
	combiner.name = block_name + "Block"
	combiner.use_collision = true
	combiner.position = block["center"]
	_geometry.add_child(combiner)
	combiner.owner = _geometry
	var slab := CSGBox3D.new()
	slab.name = "Slab"
	slab.size = Vector3(size.x, 1.5, size.y)
	slab.position = Vector3(0, -0.75, 0)
	slab.material = _materials["foundation"]
	combiner.add_child(slab)
	slab.owner = _geometry
	# Pirâmide de 4 lados, de ponta para baixo (cilindro de 4 lados girado 45°), esticada no
	# formato do quarteirão.
	var depth: float = minf(size.x, size.y) * 0.6
	var underside := CSGCylinder3D.new()
	underside.name = "Underside"
	underside.radius = 0.5 * sqrt(2.0) * minf(size.x, size.y) * 0.97
	underside.height = depth
	underside.cone = true
	underside.sides = 4
	underside.smooth_faces = false
	var stretch := Vector3(size.x / minf(size.x, size.y), 1.0, size.y / minf(size.x, size.y))
	underside.transform = Transform3D(Basis.from_scale(stretch) * Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, PI * 0.25),
			Vector3(0, -1.3 - depth * 0.5, 0))
	underside.material = _materials["rock"]
	combiner.add_child(underside)
	underside.owner = _geometry
	# Rochas enfeitando a parte de baixo da borda (só visual, abaixo do chão).
	for i in 8:
		var angle: float = i * TAU / 8.0 + size.x
		var spot: Vector3 = block["center"] + Vector3(cos(angle) * size.x * 0.42, -4.0, sin(angle) * size.y * 0.42)
		_place(_decor, NATURE + ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"][i % 3] + ".gltf", spot, i * 50.0, "none", 1.6)


# Prédio do CityKit: malha juntada (salva em meshes/) + caixa de colisão.
func _building(parent: Node3D, building_name: String, at: Vector3, rotation_y: float, spec: Dictionary) -> void:
	_kit.building(Vector3.ZERO, 0.0, spec)
	var instance := MeshInstance3D.new()
	instance.name = building_name
	instance.mesh = _kit.commit(MESH_DIR + building_name.to_snake_case() + ".res")
	instance.transform = Transform3D(Basis(Vector3.UP, rotation_y), at)
	parent.add_child(instance)
	instance.owner = _geometry
	var height: float = CityKit.building_height(spec)
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(spec["width"] * CityKit.MODULE, height, spec["depth"] * CityKit.MODULE)
	shape.shape = box
	shape.position = Vector3(0, height * 0.5, 0)
	body.add_child(shape)
	instance.add_child(body)
	body.owner = _geometry
	shape.owner = _geometry


# Piso plano (só visual, 1 cm acima da plataforma): textura em coordenadas do mundo, sem emendas.
# Espalha LAWN_PLANTS no gramado `lawn` (x, z), fora dos retângulos `skip` e dos círculos
# `avoid` ([centro, raio]). Cada planta vira um LawnPlants (MultiMesh) por faixa do gramado: uma
# chamada de desenho cada, que some de longe, sem sombra e sem colisão.
func _lawn_plants(lawn: Rect2, height: float, skip: Array, avoid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	var bands: int = 4
	for plant: Array in LAWN_PLANTS:
		var mesh: Mesh = _plant_mesh(plant[0])
		var per_band: Array[Array] = []
		for b in bands:
			per_band.append([])
		var wanted: int = roundi(lawn.get_area() * float(plant[1]))
		var tries: int = 0
		var placed: int = 0
		while placed < wanted and tries < wanted * 20:
			tries += 1
			var at := Vector2(rng.randf_range(lawn.position.x + 0.3, lawn.end.x - 0.3),
					rng.randf_range(lawn.position.y + 0.3, lawn.end.y - 0.3))
			if skip.any(func(area: Rect2) -> bool: return area.has_point(at)):
				continue
			if avoid.any(func(circle: Array) -> bool: return Vector2(circle[0].x, circle[0].z).distance_to(at) < circle[1]):
				continue
			var scale: float = rng.randf_range(plant[2], plant[3])
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
			var band: int = clampi(int((at.y - lawn.position.y) / lawn.size.y * bands), 0, bands - 1)
			per_band[band].append(Transform3D(basis, Vector3(at.x, height, at.y)))
			placed += 1
		for b in bands:
			if per_band[b].is_empty():
				continue
			# O MultiMesh é montado ao abrir a arena (LawnPlants): gerado aqui, sem janela, o Godot
			# não guardaria as posições.
			var instance := LawnPlants.new()
			instance.name = "%s%d" % [plant[0].replace("_", ""), b]
			instance.plant_mesh = mesh
			instance.transforms = LawnPlants.pack(per_band[b])
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = LAWN_VISIBLE_RANGE
			instance.visibility_range_end_margin = 4.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_decor.add_child(instance)
			# Ao entrar na árvore ele já montou o MultiMesh (vazio, sem janela): não vai para a cena.
			instance.multimesh = null
			instance.owner = _decor


# Malha da planta tirada do glTF do Nature Kit e salva em meshes/ (a cena de enfeites só aponta
# para ela).
func _plant_mesh(model: String) -> Mesh:
	var path: String = MESH_DIR + model.to_snake_case() + ".res"
	var scene: Node = (load(NATURE + model + ".gltf") as PackedScene).instantiate()
	var source := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh: Mesh = source.mesh.duplicate()
	scene.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	ResourceSaver.save(mesh, path)
	return load(path)


func _floor(parent: Node3D, material_key: String, center: Vector3, size: Vector2) -> void:
	# Lista dos pisos, para o som dos passos (ver levels/floor_surfaces.gd).
	_surfaces.append([material_key, center + Vector3.UP * 0.01, size])
	var plane := PlaneMesh.new()
	plane.size = size
	var instance := MeshInstance3D.new()
	instance.name = "Floor"
	instance.mesh = plane
	instance.material_override = _materials[material_key]
	instance.position = center + Vector3.UP * 0.01
	parent.add_child(instance)
	instance.owner = _geometry


# Poste de iluminação de ferro fundido (duas peças de coluna) com globo de luz em cima. As
# colunas entram na malha de enfeites do quarteirão; o globo é juntado no fim.
func _lamp(at: Vector3) -> void:
	var scale := Basis.from_scale(Vector3.ONE * 0.75)
	_kit.piece("Metal_Column_Small_Bottom", Transform3D(scale, at))
	_kit.piece("Metal_Column_Small_Top", Transform3D(scale, at + Vector3.UP * 2.25))
	_lamp_globes.append(at + Vector3.UP * 4.75)
	var body := StaticBody3D.new()
	body.name = "Lamp"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.15
	cylinder.height = 4.5
	shape.shape = cylinder
	shape.position = Vector3(0, 2.25, 0)
	body.add_child(shape)
	body.position = at
	_geometry.add_child(body)
	body.owner = _geometry
	shape.owner = _geometry


# Balaústre de 2 m (grade de ferro verde da ponte) ao longo de `along`, com colisão de 1 m.
func _balustrade(parent: Node3D, at: Vector3, along: Vector3) -> void:
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	_kit.piece("Trim_Wall_Guard", Transform3D(basis, at))
	var body := StaticBody3D.new()
	body.name = "Balustrade"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 0.2)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0.06)
	body.add_child(shape)
	body.transform = Transform3D(basis, at)
	parent.add_child(body)
	body.owner = _geometry
	shape.owner = _geometry


# Junta os enfeites de ferro (postes, balaústres) do quarteirão numa malha só.
func _commit_props(parent: Node3D, props_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = props_name
	instance.mesh = _kit.commit(MESH_DIR + props_name.to_snake_case() + ".res")
	parent.add_child(instance)
	instance.owner = _geometry


# Globos dos postes: uma esfera que brilha (sem luz de verdade: luz dinâmica pesa no celular).
func _build_lamp_globes() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 10
	sphere.rings = 6
	for at: Vector3 in _lamp_globes:
		var globe := MeshInstance3D.new()
		globe.name = "LampGlobe"
		globe.mesh = sphere
		globe.material_override = _materials["lamp"]
		globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		globe.position = at
		_decor.add_child(globe)
		globe.owner = _decor


# Ponte: perfil de mármore extrudado. Patamares planos de 1 m entram em cada quarteirão na altura
# do chão dele (1 cm abaixo, para as superfícies não piscarem) e a rampa fica só no vão: o
# personagem não sobe degrau, então as pontas não podem ter "quina". `from` e `to` são as bordas.
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
	# Grama pintada à mão (antes era um verde liso), com relevo; um tile a cada 4 m.
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = load(GROUND + "grass_01_basecolor.jpg")
	# A textura é verde-limão: puxada para o verde das folhas das árvores.
	grass.albedo_color = Color(0.72, 0.86, 0.72)
	grass.normal_enabled = true
	grass.normal_texture = load(GROUND + "grass_01_normal.jpg")
	grass.normal_scale = 0.6
	grass.roughness = 1.0
	grass.uv1_triplanar = true
	grass.uv1_world_triplanar = true
	grass.uv1_scale = Vector3.ONE * 0.25
	_materials["grass"] = grass
	# A rocha da base fica só com a luz do céu (o sol não bate embaixo): textura de terra clara.
	_materials["rock"] = _world_material("T_Dirt_BaseColor.png", 0.12, Color(1.8, 1.7, 1.55))
	_materials["foundation"] = _world_material("T_Concrete_BaseColor.png", 0.25, Color(0.86, 0.8, 0.7))
	_materials["marble"] = _world_material("T_MarbleFloor_BaseColor.png", 0.25, Color.WHITE)
	_materials["asphalt"] = _world_material("T_Concrete_Asphalt_BaseColor.png", 0.15, Color(0.75, 0.75, 0.75))
	_materials["sidewalk"] = _world_material("T_Concrete_BaseColor.png", 0.33, Color(0.92, 0.9, 0.86))
	_materials["bridge"] = _world_material("T_MarbleFloor_BaseColor.png", 0.5, Color.WHITE)
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
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(0.98, 0.98, 1.0)
	cloud.roughness = 1.0
	cloud.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_materials["cloud"] = cloud
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.93, 0.75)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.55)
	lamp.emission_energy_multiplier = 1.5
	_materials["lamp"] = lamp


# Textura projetada pelas coordenadas do mundo: `scale` = repetições por metro.
func _world_material(texture: String, scale: float, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(CITY + texture)
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material


func _save(scene_root: Node, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := PackedScene.new()
	var err: Error = packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved %s (%s): %d nodes" % [path, error_string(err), scene_root.find_children("*", "", true, false).size()])
