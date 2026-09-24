class_name CityKit
extends RefCounted
## Monta prédios (ferramenta de construção de mapas, não roda no jogo) com as peças modulares
## do Downtown City MegaKit e junta cada prédio numa malha só, com uma superfície por material
## e níveis de detalhe (LOD) automáticos: poucas chamadas de desenho no celular.
##
## Peças de parede: 2 m (ou 4 m) de largura por 3 m (ou 4 m) de altura; a face de fora olha para
## +Z e a espessura vai para -Z. Um prédio é um retângulo de `width` x `depth` módulos de 2 m.
## Quantos módulos uma peça ocupa sai da largura dela (2 m = 1, 4 m = 2).
##
## Materiais (2026-09-24, Downtown City MegaKit [Source]): as peças já chegam com os materiais do
## projeto (`tools/city_import_script.gd`): o shader do pacote (desgaste nas quinas pelo 2º UV e
## sujeira pela cor do vértice, por isso a cor do vértice e o 2º UV são mantidos) e a sala atrás
## da janela (`fake_interior.gdshader`). Nas peças com sala o vidro sai (o shader da sala já faz o
## vidro) e cada janela (pedaço solto da superfície da sala) ganha o seu sorteio (acesa ou não,
## qual sala, qual cortina) na cor do vértice. Peça sem cor de vértice ganha branco (= sem
## sujeira) e sem 2º UV ganha zeros.

const PIECES_DIR := "res://assets/models/city/downtown/"
const MATERIALS_DIR := "res://assets/materials/city/"
const MODULE: float = 2.0
## Altura padrão de um andar (cada estilo pode ter a sua: `floor_height`).
const FLOOR_HEIGHT: float = 3.0
## Altura do telhado mansarda (peças Roof_SlateCornice_*).
const MANSARD_HEIGHT: float = 3.2
## Altura da cornija do telhado plano.
const CORNICE_HEIGHT: float = 1.0
## Altura da faixa lisa em cima do térreo (onde vão os letreiros das lojas).
const BAND_HEIGHT: float = 1.0
## Superfícies que nunca aparecem.
const SKIPPED_MATERIALS: Array[String] = []
## Sala atrás da janela e o vidro (que sai das peças que têm sala).
const ROOM_MATERIAL := "MI_FakeInterior"
const GLASS_MATERIAL := "MI_Glass"
## Semente dos sorteios das janelas (mesma semente = mesma cidade a cada build).
const ROOM_SEED: int = 1900

## Estilos de prédio: peças do térreo, dos andares, da porta, dos cantos, da cornija e da faixa.
##   floor_height  altura do andar (3 ou 4 m, conforme as peças)
##   ground/upper/top  sequência de peças do térreo, dos andares do meio e do último
##   door, door_leaves  batente e onde vão as folhas da porta ([deslocamento x, peça])
##   plain, plain_window  lados simples (os que não dão para a área de jogo)
##   corner  [baixo, meio, cima] da coluna de canto (esticada na altura do andar)
##   cornice  [meio, ponta] da cornija do telhado plano
##   band  peça de 1 m de altura da faixa em cima do térreo (se o prédio pedir `band`)
const STYLES: Dictionary = {
	# Casa de tijolo vermelho (residencial), janelas com moldura.
	"brick": {
		"ground": ["Brick_BottomTrim", "Brick_Window_Trim_Single"],
		"door": "DoorFrame_Wooden", "door_leaves": [[0.5, "Door_1"]],
		"upper": ["Brick_Window_Trim", "Brick_Plain_3", "Brick_Window_Trim_Single"],
		"top": ["Brick_Window_Trim", "Brick_TopTrim", "Brick_Window_Trim_Single"],
		"plain": "Brick_Plain_3", "plain_window": "Brick_Window_Square_Single",
		"corner": ["Brick_CornerColumn_Bottom", "Brick_CornerColumn_Center", "Brick_CornerColumn_Top"],
		"cornice": ["Cornice_Trim_Center", "Cornice_Trim_R"], "band": "Brick_Plain_1",
	},
	# Casa de tijolo com janelas salientes (bay windows) nos andares de cima.
	"brick_bay": {
		"ground": ["Brick_BottomTrim", "Brick_Window_Trim_Single"],
		"door": "DoorFrame_Wooden", "door_leaves": [[0.5, "Door_1"]],
		"upper": ["Brick_BayWindow", "Brick_Window_Trim_Single"],
		"top": ["Brick_Window_Trim", "Brick_TopTrim", "Brick_Window_Trim_Single"],
		"plain": "Brick_Plain_3", "plain_window": "Brick_Window_Square_Single",
		"corner": ["Brick_CornerColumn_Bottom", "Brick_CornerColumn_Center", "Brick_CornerColumn_Top"],
		"cornice": ["Cornice_Trim_Center", "Cornice_Trim_R"], "band": "Brick_Plain_1",
	},
	# Comércio: vitrines de ferro no térreo, tijolo claro com janelas em arco em cima.
	"shop": {
		"ground": ["Metal_FirstFloor_Window"],
		"door": "DoorFrame_Metal_Single", "door_leaves": [[0.5, "Door_2"]],
		"upper": ["Brick_Inset_Window_Curved", "Brick_Inset"],
		"top": ["Brick_Inset_Window_Curved_Small", "Brick_Inset"],
		"plain": "Brick_Plain_3", "plain_window": "Brick_Window_Square_Single",
		"corner": ["Brick_CornerColumn_Bottom", "Brick_CornerColumn_Center", "Brick_CornerColumn_Top"],
		"cornice": ["Cornice_Trim_Center", "Cornice_Trim_R"], "band": "Brick_Plain_1",
	},
	# Prédio "cívico" de pedra clara (banco, estação): térreo verde com colunas.
	"civic": {
		"ground": ["Trim_FirstFloor_Window"],
		"door": "DoorFrame_Trim", "door_leaves": [],
		"upper": ["Trim_Window", "Trim_Plain_3"],
		"top": ["Trim_Window", "Trim_Plain_3"],
		"plain": "Trim_Plain_3", "plain_window": "Trim_Window",
		"corner": ["Trim_Column_Bottom", "Trim_Column_Center", "Trim_Column_Top"],
		"cornice": ["Cornice_Trim_Center", "Cornice_Trim_R"], "band": "Trim_Plain_3",
	},
	# Banco de mármore: andares de 4 m, vitrines altas, janelas triplas e colunas grossas.
	"bank": {
		"floor_height": 4.0,
		"ground": ["Marble_ShopWindow"],
		"door": "DoorFrame_Marble", "door_leaves": [[0.0, "Door_4"], [1.0, "Door_4"]],
		"upper": ["Marble_WindowTriple"],
		"top": ["Marble_WindowTriple"],
		"plain": "Marble_Plain_4", "plain_window": "Marble_WindowTriple",
		"corner": ["Marble_Column_Large_Bottom", "Marble_Column_Large_Center", "Marble_Column_Large_Top"],
		"cornice": ["Cornice_Marble_Center", "Cornice_Marble_R"], "band": "Marble_Plain_1",
	},
	# Hotel de tijolo branco com janelas salientes; térreo de vitrines com moldura verde.
	"hotel": {
		"ground": ["Trim_FirstFloor_Window"],
		"door": "DoorFrame_Trim", "door_leaves": [[0.5, "Door_4"]],
		"upper": ["Trim_BayWindow", "WhiteBrick_Window"],
		"top": ["WhiteBrick_Window"],
		"plain": "WhiteBrick_Plain_3", "plain_window": "WhiteBrick_Window",
		"corner": ["WhiteBrick_Column", "WhiteBrick_Column", "WhiteBrick_Column"],
		"cornice": ["Cornice_WhiteBrick_Center", "Cornice_WhiteBrick_R"], "band": "WhiteBrick_Plain_1",
	},
	# Cortiço de tijolo gasto e escuro, janelões de fábrica.
	"tenement": {
		"ground": ["WornBrick_Bottom"],
		"door": "DoorFrame_WornBrick", "door_leaves": [[0.0, "Door_1"], [1.0, "Door_1"]],
		"upper": ["WornBrick_WindowTriple", "WornBrick_WindowLarge"],
		"top": ["WornBrick_WindowLarge_Top", "WornBrick_WindowTriple"],
		"plain": "WornBrick_Plain_3", "plain_window": "WornBrick_WindowTriple",
		"corner": ["WornBrick_90Angle_L", "WornBrick_90Angle_L", "WornBrick_90Angle_L"],
		"cornice": ["Cornice_WornBrick_Center", "Cornice_WornBrick_R"], "band": "WornBrick_Plain_1",
	},
}

var piece_count: int = 0

var _parts: Dictionary = {}  # peça -> [[Mesh, Transform3D], ...]
var _bounds: Dictionary = {}  # peça -> AABB (no espaço da peça)
var _materials: Dictionary = {}  # nome do material -> Material compartilhado (.tres)
var _batch: Dictionary = {}  # caminho do material -> SurfaceTool
var _glass: StandardMaterial3D
var _prepared: Dictionary = {}  # [malha, superfície] -> ArrayMesh com cor de vértice e 2º UV
var _room_rng := RandomNumberGenerator.new()


func _init() -> void:
	_room_rng.seed = ROOM_SEED


## Coloca a peça `piece_name` com a transformação `xform` no prédio atual.
func piece(piece_name: String, xform: Transform3D) -> void:
	var parts: Array = _parts_of(piece_name)
	var has_room: bool = _has_room(parts)
	for part: Array in parts:
		var mesh: Mesh = part[0]
		var local: Transform3D = xform * (part[1] as Transform3D)
		for surface: int in mesh.get_surface_count():
			var source: Material = mesh.surface_get_material(surface)
			var material_name: String = _material_name(source)
			if material_name in SKIPPED_MATERIALS or (has_room and material_name == GLASS_MATERIAL):
				continue
			var material: Material = _shared_material(source)
			var key: String = material.resource_path
			if not _batch.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				_batch[key] = tool
			var prepared: ArrayMesh
			if material_name == ROOM_MATERIAL:
				prepared = _with_window_seeds(mesh, surface)
			else:
				prepared = _prepared_surface(mesh, surface)
			(_batch[key] as SurfaceTool).append_from(prepared, 0, local)
	piece_count += 1


## Fecha o prédio atual: junta as peças numa malha com LOD e salva em `path` (.res).
func commit(path: String) -> Mesh:
	var importer := ImporterMesh.new()
	for key: String in _batch:
		var tool: SurfaceTool = _batch[key]
		tool.index()
		# Algumas peças vêm sem tangentes: misturadas com as que têm, ficariam com tangente zero e
		# o mapa de relevo deixaria a superfície preta. Recalcula para a malha toda.
		tool.generate_tangents()
		var arrays: Array = tool.commit_to_arrays()
		# Canais extras (custom, ossos) de algumas peças não servem para prédio parado. A cor do
		# vértice fica: é a sujeira do shader do pacote e o sorteio das janelas.
		for channel: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
				Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			arrays[channel] = null
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, load(key), key.get_file().get_basename())
	importer.generate_lods(25.0, 60.0, [])
	var mesh: ArrayMesh = importer.get_mesh()
	_batch.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(mesh, path)
	return load(path)


## Prédio completo com a frente (+Z) centrada em `origin`, virado `rotation_y` radianos.
## spec: width, depth (módulos de 2 m), floors, style (ver STYLES), roof ("mansard"/"flat"),
## detailed (4 bools: frente, direita, fundos, esquerda = lados com janelas caprichadas; os outros
## ficam simples), door_side (lado da porta, -1 = sem porta), band (faixa lisa em cima do térreo).
## Enfeites (todos opcionais; `side` = 0 frente, 1 direita, 2 fundos, 3 esquerda; `u` = posição
## ao longo do lado, em metros a partir do meio):
##   awnings: {side, piece, skip_door}  toldo em cima de cada janela do térreo, um sim, um não
##   signs: [{side, piece, u, y, out, scale}]  letreiros presos na parede (`out` = quanto sai dela)
##   fire_escape: {side, u}  escada de incêndio do 1º andar até o último
func building(origin: Vector3, rotation_y: float, spec: Dictionary) -> void:
	var width: int = spec.get("width", 5)
	var depth: int = spec.get("depth", 5)
	var floors: int = spec.get("floors", 3)
	var style: Dictionary = STYLES[spec.get("style", "brick")]
	var detailed: Array = spec.get("detailed", [true, true, true, true])
	var door_side: int = spec.get("door_side", 0)
	var floor_height: float = style.get("floor_height", FLOOR_HEIGHT)
	var band: float = BAND_HEIGHT if spec.get("band", false) else 0.0
	var base := Transform3D(Basis(Vector3.UP, rotation_y), origin)
	var top_y: float = floors * floor_height + band
	for side in 4:
		var length: int = width if side % 2 == 0 else depth
		var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
		var side_basis := Basis(Vector3.UP, side * PI * 0.5)
		for floor_index in floors:
			var y: float = floor_index * floor_height + (band if floor_index > 0 else 0.0)
			_facade_row(base, side_basis, length, half, y, floor_index, floors, style, detailed[side],
					side == door_side and floor_index == 0)
		if band > 0.0:
			_band_row(base, side_basis, length, half, floor_height, style["band"])
		_corner_column(base, side_basis, length, half, floors, floor_height, band, style)
	if spec.get("roof", "mansard") == "mansard":
		_mansard(base, width, depth, top_y)
	else:
		_flat_roof(base, width, depth, top_y, style["cornice"])
	if spec.has("awnings"):
		_awnings(base, width, depth, style, spec, door_side)
	for sign: Dictionary in spec.get("signs", []):
		_sign(base, width, depth, sign)
	if spec.has("fire_escape"):
		_fire_escape(base, width, depth, floors, floor_height, band, spec["fire_escape"])


## Altura total do prédio (paredes + telhado), para a colisão.
static func building_height(spec: Dictionary) -> float:
	var style: Dictionary = STYLES[spec.get("style", "brick")]
	var height: float = spec.get("floors", 3) * style.get("floor_height", FLOOR_HEIGHT)
	height += BAND_HEIGHT if spec.get("band", false) else 0.0
	return height + (MANSARD_HEIGHT if spec.get("roof", "mansard") == "mansard" else CORNICE_HEIGHT)


## Transformação de um ponto de um lado do prédio: `u` ao longo do lado (metros a partir do
## meio), `y` de altura e `out` para fora da parede.
static func side_transform(base: Transform3D, width: int, depth: int, side: int, u: float, y: float,
		out: float = 0.0) -> Transform3D:
	var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
	var side_basis := Basis(Vector3.UP, side * PI * 0.5)
	return base * Transform3D(side_basis, side_basis * Vector3(u, y, half + out))


# Uma fileira de peças de um andar num lado do prédio. Peças de 4 m ocupam 2 módulos.
func _facade_row(base: Transform3D, side_basis: Basis, length: int, half: float, y: float, floor_index: int,
		floors: int, style: Dictionary, detailed: bool, with_door: bool) -> void:
	var pattern: Array = style["ground"] if floor_index == 0 else (style["top"] if floor_index == floors - 1 else style["upper"])
	var door_span: int = _span(style["door"])
	# Porta no meio do lado (peças de 4 m também ficam centralizadas).
	var door_module: int = (length - door_span) / 2 if with_door else -1
	var module: int = 0
	var step: int = 0
	while module < length:
		var piece_name: String
		if module == door_module:
			piece_name = style["door"]
		elif not detailed:
			piece_name = style["plain_window"] if (module + floor_index) % 3 == 1 else style["plain"]
		else:
			piece_name = pattern[step % pattern.size()]
			step += 1
		var span: int = _span(piece_name)
		var overlaps_door: bool = door_module >= 0 and piece_name != style["door"] \
				and module < door_module + door_span and module + span > door_module
		if module + span > length or overlaps_door:
			# Não cabe (ou passaria por cima da porta): um módulo de parede lisa.
			piece_name = style["plain"] if _span(style["plain"]) == 1 else _plain_2m(style)
			span = 1
		var u: float = (module + span * 0.5) * MODULE - length * MODULE * 0.5
		piece(piece_name, base * Transform3D(side_basis, side_basis * Vector3(u, y, half)))
		if piece_name == style["door"]:
			for leaf: Array in style.get("door_leaves", []):
				piece(leaf[1], base * Transform3D(side_basis, side_basis * Vector3(u + leaf[0], y, half - 0.05)))
		module += span


# Faixa lisa de 1 m em cima do térreo, no lado inteiro.
func _band_row(base: Transform3D, side_basis: Basis, length: int, half: float, y: float, band_piece: String) -> void:
	var scale_y: float = BAND_HEIGHT / maxf(_bounds_of(band_piece).size.y, 0.01)
	for module in length:
		var u: float = (module + 0.5) * MODULE - length * MODULE * 0.5
		piece(band_piece, base * Transform3D(side_basis.scaled(Vector3(1.0, scale_y, 1.0)), side_basis * Vector3(u, y, half)))


# Parede lisa de 2 m do estilo (para quando a lisa dele é de 4 m).
func _plain_2m(style: Dictionary) -> String:
	for candidate: String in [style["plain"], style["plain_window"], "Brick_Plain_3"]:
		if _span(candidate) == 1:
			return candidate
	return "Brick_Plain_3"


# Coluna de canto: uma peça por andar (esticada na altura do andar) e mais uma na faixa.
func _corner_column(base: Transform3D, side_basis: Basis, length: int, half: float, floors: int,
		floor_height: float, band: float, style: Dictionary) -> void:
	var corner: Vector3 = side_basis * Vector3(length * MODULE * 0.5, 0.0, half)
	var names: Array = style["corner"]
	for floor_index in floors:
		var piece_name: String = names[0] if floor_index == 0 else (names[2] if floor_index == floors - 1 else names[1])
		var y: float = floor_index * floor_height + (band if floor_index > 0 else 0.0)
		var scale_y: float = floor_height / maxf(_bounds_of(piece_name).size.y, 0.01)
		piece(piece_name, base * Transform3D(side_basis.scaled(Vector3(1.0, scale_y, 1.0)), corner + Vector3.UP * y))
	if band > 0.0:
		var middle: String = names[1]
		var scale_band: float = band / maxf(_bounds_of(middle).size.y, 0.01)
		piece(middle, base * Transform3D(side_basis.scaled(Vector3(1.0, scale_band, 1.0)), corner + Vector3.UP * floor_height))


# Telhado mansarda de ardósia: peças de 2x2 m pela borda (cantos e lucarnas) e laje no meio.
func _mansard(base: Transform3D, width: int, depth: int, top_y: float) -> void:
	for side in 4:
		var length: int = width if side % 2 == 0 else depth
		var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
		var side_basis := Basis(Vector3.UP, side * PI * 0.5)
		for module in length:
			var u: float = (module + 0.5) * MODULE - length * MODULE * 0.5
			# A peça de canto dobra para a esquerda (-X): fica no começo de cada lado e cobre o
			# fim do lado anterior.
			var piece_name: String = "Roof_SlateCornice_Center"
			if module == 0:
				piece_name = "Roof_SlateCornice_Corner"
			elif module == length - 1:
				continue
			elif module % 2 == 0:
				piece_name = "Roof_SlateCornice_Window_1"
			piece(piece_name, base * Transform3D(side_basis, side_basis * Vector3(u, top_y, half)))
	_roof_slab(base, width - 2, depth - 2, top_y + MANSARD_HEIGHT)


func _flat_roof(base: Transform3D, width: int, depth: int, top_y: float, cornice: Array) -> void:
	for side in 4:
		var length: int = width if side % 2 == 0 else depth
		var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
		var side_basis := Basis(Vector3.UP, side * PI * 0.5)
		for module in length:
			var u: float = (module + 0.5) * MODULE - length * MODULE * 0.5
			# A versão R passa um pouco do fim e fecha o canto com a cornija do lado seguinte.
			var piece_name: String = cornice[1] if module == length - 1 else cornice[0]
			piece(piece_name, base * Transform3D(side_basis, side_basis * Vector3(u, top_y, half)))
	_roof_slab(base, width, depth, top_y)


# Laje de 2x2 m cobrindo `width` x `depth` módulos, centrada.
func _roof_slab(base: Transform3D, width: int, depth: int, y: float) -> void:
	for ix in width:
		for iz in depth:
			var at := Vector3((ix + 0.5) * MODULE - width * MODULE * 0.5, y, (iz + 0.5) * MODULE - depth * MODULE * 0.5)
			piece("Roof_2x2", base * Transform3D(Basis(), at))


# Toldos no térreo de um lado: um em cima de cada janela, pulando uma (não se encostam) e a porta.
func _awnings(base: Transform3D, width: int, depth: int, style: Dictionary, spec: Dictionary, door_side: int) -> void:
	var awnings: Dictionary = spec["awnings"]
	var side: int = awnings.get("side", 0)
	var length: int = width if side % 2 == 0 else depth
	var door_span: int = _span(style["door"])
	var door_module: int = (length - door_span) / 2 if side == door_side else -100
	var start: int = awnings.get("start", 0)
	for module in range(start, length, 2):
		if module >= door_module and module < door_module + door_span:
			continue
		var u: float = (module + 0.5) * MODULE - length * MODULE * 0.5
		piece(awnings["piece"], side_transform(base, width, depth, side, u, 0.0))


func _sign(base: Transform3D, width: int, depth: int, sign: Dictionary) -> void:
	var at: Transform3D = side_transform(base, width, depth, sign.get("side", 0), sign.get("u", 0.0),
			sign.get("y", 3.5), sign.get("out", 0.02))
	piece(sign["piece"], at * Transform3D.IDENTITY.scaled(Vector3.ONE * sign.get("scale", 1.0)))


# Escada de incêndio: plataforma com escada em cada andar do 1º ao penúltimo e só a plataforma no
# último; a do 1º andar tem a escada de mão que desce até a rua.
func _fire_escape(base: Transform3D, width: int, depth: int, floors: int, floor_height: float, band: float,
		escape: Dictionary) -> void:
	for floor_index in range(1, floors):
		var y: float = floor_index * floor_height + band
		var piece_name: String = "Prop_FireEscape_Center"
		if floor_index == 1:
			piece_name = "Prop_FireEscape_Bottom"
		if floor_index == floors - 1:
			piece_name = "Prop_FireEscape_Top"
		piece(piece_name, side_transform(base, width, depth, escape.get("side", 1), escape.get("u", 0.0), y))


# Quantos módulos de 2 m a peça ocupa (pela largura dela).
func _span(piece_name: String) -> int:
	return maxi(roundi(_bounds_of(piece_name).size.x / MODULE), 1)


func _bounds_of(piece_name: String) -> AABB:
	if not _bounds.has(piece_name):
		var box := AABB()
		var first: bool = true
		for part: Array in _parts_of(piece_name):
			var mesh: Mesh = part[0]
			var local: AABB = (part[1] as Transform3D) * mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		_bounds[piece_name] = box
	return _bounds[piece_name]


func _parts_of(piece_name: String) -> Array:
	if not _parts.has(piece_name):
		var scene: Node = (load(PIECES_DIR + piece_name + ".gltf") as PackedScene).instantiate()
		var parts: Array = []
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			var xform := Transform3D.IDENTITY
			var current: Node = instance
			while current != null and current != scene:
				if current is Node3D:
					xform = (current as Node3D).transform * xform
				current = current.get_parent()
			parts.append([instance.mesh, xform])
		scene.free()
		_parts[piece_name] = parts
	return _parts[piece_name]


# A peça tem sala atrás da janela (e aí o vidro dela sai).
func _has_room(parts: Array) -> bool:
	for part: Array in parts:
		var mesh: Mesh = part[0]
		for surface: int in mesh.get_surface_count():
			if _material_name(mesh.surface_get_material(surface)) == ROOM_MATERIAL:
				return true
	return false


# Nome do material: o do arquivo do projeto (script de importação) ou o que veio no glTF.
func _material_name(material: Material) -> String:
	if material == null:
		return "MI_Default"
	if material.resource_path.begins_with(MATERIALS_DIR):
		return material.resource_path.get_file().get_basename()
	return material.resource_name


# A superfície pronta para juntar: com cor de vértice (branca = sem sujeira) e 2º UV.
func _prepared_surface(mesh: Mesh, surface: int) -> ArrayMesh:
	var key: Array = [mesh, surface]
	if not _prepared.has(key):
		_prepared[key] = _as_mesh(_arrays_with_color_and_uv2(mesh, surface), mesh.surface_get_material(surface))
	return _prepared[key]


# A superfície das salas com um sorteio por janela: cada pedaço solto da superfície (triângulos
# que dividem vértices) é uma janela e ganha a sua cor (r = acesa, g = qual sala, b = cortina).
func _with_window_seeds(mesh: Mesh, surface: int) -> ArrayMesh:
	var arrays: Array = _arrays_with_color_and_uv2(mesh, surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(vertices.size())
		for i in vertices.size():
			indices[i] = i
	# União dos vértices de cada triângulo; vértices na mesma posição também se juntam (cantos
	# duplicados por causa das coordenadas de textura).
	var parent := PackedInt32Array()
	parent.resize(vertices.size())
	for i in vertices.size():
		parent[i] = i
	var by_position: Dictionary = {}
	for i in vertices.size():
		var key: Vector3i = Vector3i((vertices[i] * 1000.0).round())
		if by_position.has(key):
			_union(parent, i, by_position[key])
		else:
			by_position[key] = i
	for t in range(0, indices.size(), 3):
		_union(parent, indices[t], indices[t + 1])
		_union(parent, indices[t], indices[t + 2])
	var seeds: Dictionary = {}
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	for i in vertices.size():
		var root: int = _find(parent, i)
		if not seeds.has(root):
			seeds[root] = Color(_room_rng.randf(), _room_rng.randf(), _room_rng.randf())
		colors[i] = seeds[root]
	arrays[Mesh.ARRAY_COLOR] = colors
	return _as_mesh(arrays, mesh.surface_get_material(surface))


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var root_a: int = _find(parent, a)
	var root_b: int = _find(parent, b)
	if root_a != root_b:
		parent[root_a] = root_b


# Os dados da superfície garantindo cor de vértice (branca) e 2º UV, sem os canais extras.
func _arrays_with_color_and_uv2(mesh: Mesh, surface: int) -> Array:
	var arrays: Array = mesh.surface_get_arrays(surface)
	# Canais extras (custom, ossos) de algumas peças não servem para prédio parado (e pediriam
	# formato especial na cópia).
	for channel: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3,
			Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		arrays[channel] = null
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if arrays[Mesh.ARRAY_COLOR] == null:
		var colors := PackedColorArray()
		colors.resize(count)
		colors.fill(Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = colors
	if arrays[Mesh.ARRAY_TEX_UV2] == null:
		var uv2 := PackedVector2Array()
		uv2.resize(count)
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays


static func _as_mesh(arrays: Array, material: Material) -> ArrayMesh:
	var copy := ArrayMesh.new()
	copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	copy.surface_set_material(0, material)
	return copy


# Um material por nome: o do projeto (já vem pelo script de importação) ou, para peça sem ele,
# uma cópia salva uma vez em MATERIALS_DIR e usada por todos os prédios.
func _shared_material(source: Material) -> Material:
	if source != null and source.resource_path.begins_with(MATERIALS_DIR):
		return source
	var material_name: String = source.resource_name if source != null else "MI_Default"
	if not _materials.has(material_name):
		var path: String = MATERIALS_DIR + material_name + ".tres"
		var material: Material
		if material_name == "MI_Glass":
			material = _glass_material()
		else:
			material = source.duplicate()
			# Sem cor de vértice: misturando peças com e sem cor, as sem cor ficariam pretas.
			(material as BaseMaterial3D).vertex_color_use_as_albedo = false
		material.resource_name = material_name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALS_DIR))
		ResourceSaver.save(material, path)
		_materials[material_name] = load(path)
	return _materials[material_name]


# Vidro opaco, escuro e brilhante (reflete o céu), para peças sem sala atrás (portas, vitrines).
# Transparência custa caro no celular.
func _glass_material() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.11, 0.15, 0.19)
	glass.metallic = 0.7
	glass.roughness = 0.12
	return glass
