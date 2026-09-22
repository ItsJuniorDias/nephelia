class_name CityKit
extends RefCounted
## Monta prédios (ferramenta de construção de mapas, não roda no jogo) com as peças modulares
## do Downtown City MegaKit e junta cada prédio numa malha só, com uma superfície por material
## e níveis de detalhe (LOD) automáticos: poucas chamadas de desenho no celular.
##
## Peças de parede: 2 m (ou 4 m) de largura por 3 m de altura; a face de fora olha para +Z e a
## espessura vai para -Z. Um prédio é um retângulo de `width` x `depth` módulos de 2 m.

const PIECES_DIR := "res://assets/models/city/downtown/"
const MATERIALS_DIR := "res://assets/materials/city/"
const MODULE: float = 2.0
const FLOOR_HEIGHT: float = 3.0
## Altura do telhado mansarda (peças Roof_SlateCornice_*).
const MANSARD_HEIGHT: float = 3.2
## Superfícies que nunca aparecem (os prédios são fechados e o vidro é opaco).
const SKIPPED_MATERIALS: Array[String] = ["MI_FakeInterior", "MI_FakeInterior_1", "MI_FakeInterior_2",
		"MI_FakeInterior_3", "MI_FakeInterior_4", "MI_InteriorWall", "MI_InteriorFloor", "MI_InteriorRoof"]

## Estilos de prédio: peças do térreo, dos andares, da porta e dos cantos.
const STYLES: Dictionary = {
	# Casa de tijolo vermelho (residencial), janelas com moldura.
	"brick": {
		"ground": ["Brick_BottomTrim", "Brick_Window_Trim_Single"],
		"door": "DoorFrame_Wooden", "door_leaf": "Door_1",
		"upper": ["Brick_Window_Trim", "Brick_Plain_3", "Brick_Window_Trim_Single"],
		"top": ["Brick_Window_Trim", "Brick_TopTrim", "Brick_Window_Trim_Single"],
		"plain": "Brick_Plain_3", "plain_window": "Brick_Window_Square_Single",
		"corner": "brick_column",
	},
	# Comércio: vitrines de ferro no térreo, tijolo claro com janelas em arco em cima.
	"shop": {
		"ground": ["Metal_FirstFloor_Window"],
		"door": "DoorFrame_Metal_Single", "door_leaf": "Door_2",
		"upper": ["Brick_Inset_Window_Curved", "Brick_Inset"],
		"top": ["Brick_Inset_Window_Curved_Small", "Brick_Inset"],
		"plain": "Brick_Plain_3", "plain_window": "Brick_Window_Square_Single",
		"corner": "brick_column",
	},
	# Prédio "cívico" de pedra clara (banco, estação): térreo verde com colunas.
	"civic": {
		"ground": ["Trim_FirstFloor_Window_001"],
		"door": "DoorFrame_Trim", "door_leaf": "",
		"upper": ["Trim_Window", "Trim_Plain_3"],
		"top": ["Trim_Window", "Trim_Plain_3"],
		"plain": "Trim_Plain_3", "plain_window": "Trim_Window",
		"corner": "trim_column",
	},
}

var piece_count: int = 0

var _parts: Dictionary = {}  # peça -> [[Mesh, Transform3D], ...]
var _materials: Dictionary = {}  # nome do material -> Material compartilhado (.tres)
var _batch: Dictionary = {}  # caminho do material -> SurfaceTool
var _glass: StandardMaterial3D


## Coloca a peça `piece_name` com a transformação `xform` no prédio atual.
func piece(piece_name: String, xform: Transform3D) -> void:
	for part: Array in _parts_of(piece_name):
		var mesh: Mesh = part[0]
		var local: Transform3D = xform * (part[1] as Transform3D)
		for surface: int in mesh.get_surface_count():
			var source: Material = mesh.surface_get_material(surface)
			if source != null and source.resource_name in SKIPPED_MATERIALS:
				continue
			var material: Material = _shared_material(source)
			var key: String = material.resource_path
			if not _batch.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				_batch[key] = tool
			(_batch[key] as SurfaceTool).append_from(mesh, surface, local)
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
		# Canais extras (cor, custom, ossos) de algumas peças não servem para prédio parado.
		for channel: int in [Mesh.ARRAY_COLOR, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
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
## spec: width, depth (módulos de 2 m), floors, style ("brick"/"shop"/"civic"), roof
## ("mansard"/"flat"), detailed (4 bools: frente, direita, fundos, esquerda = lados com janelas
## caprichadas; os outros ficam simples), door_side (lado da porta, -1 = sem porta).
func building(origin: Vector3, rotation_y: float, spec: Dictionary) -> void:
	var width: int = spec.get("width", 5)
	var depth: int = spec.get("depth", 5)
	var floors: int = spec.get("floors", 3)
	var style: Dictionary = STYLES[spec.get("style", "brick")]
	var detailed: Array = spec.get("detailed", [true, true, true, true])
	var door_side: int = spec.get("door_side", 0)
	var base := Transform3D(Basis(Vector3.UP, rotation_y), origin)
	var top_y: float = floors * FLOOR_HEIGHT
	for side in 4:
		var length: int = width if side % 2 == 0 else depth
		var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
		var side_basis := Basis(Vector3.UP, side * PI * 0.5)
		for floor_index in floors:
			_facade_row(base, side_basis, length, half, floor_index, floors, style, detailed[side],
					side == door_side and floor_index == 0)
		_corner_column(base, side_basis, length, half, floors, style)
	if spec.get("roof", "mansard") == "mansard":
		_mansard(base, width, depth, top_y)
	else:
		_flat_roof(base, width, depth, top_y)


## Altura total do prédio (paredes + telhado), para a colisão.
static func building_height(spec: Dictionary) -> float:
	var height: float = spec.get("floors", 3) * FLOOR_HEIGHT
	return height + (MANSARD_HEIGHT if spec.get("roof", "mansard") == "mansard" else 1.0)


# Uma fileira de peças de um andar num lado do prédio. Peças de 4 m ocupam 2 módulos.
func _facade_row(base: Transform3D, side_basis: Basis, length: int, half: float, floor_index: int,
		floors: int, style: Dictionary, detailed: bool, with_door: bool) -> void:
	var y: float = floor_index * FLOOR_HEIGHT
	var pattern: Array = style["ground"] if floor_index == 0 else (style["top"] if floor_index == floors - 1 else style["upper"])
	var door_module: int = length / 2 if with_door else -1
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
		var span: int = 2 if _is_wide(piece_name) else 1
		if module + span > length or (door_module >= module and door_module < module + span and span > 1):
			# Não cabe (ou passaria por cima da porta): usa a versão de 2 m.
			piece_name = style["plain"] if piece_name != style["door"] else piece_name
			span = 1
		var u: float = (module + span * 0.5) * MODULE - length * MODULE * 0.5
		piece(piece_name, base * Transform3D(side_basis, side_basis * Vector3(u, y, half)))
		if piece_name == style["door"] and style["door_leaf"] != "":
			piece(style["door_leaf"], base * Transform3D(side_basis, side_basis * Vector3(u + 0.5, y, half - 0.05)))
		module += span


func _corner_column(base: Transform3D, side_basis: Basis, length: int, half: float, floors: int,
		style: Dictionary) -> void:
	var corner: Vector3 = side_basis * Vector3(length * MODULE * 0.5, 0.0, half)
	var names: Array[String]
	if style["corner"] == "trim_column":
		names = ["Trim_Column_Bottom", "Trim_Column_Center", "Trim_Column_Top"]
	else:
		names = ["Brick_CornerColumn_Bottom", "Brick_CornerColumn_Center", "Brick_CornerColumn_Top"]
	for floor_index in floors:
		var piece_name: String = names[0] if floor_index == 0 else (names[2] if floor_index == floors - 1 else names[1])
		piece(piece_name, base * Transform3D(side_basis, corner + Vector3.UP * floor_index * FLOOR_HEIGHT))


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


func _flat_roof(base: Transform3D, width: int, depth: int, top_y: float) -> void:
	for side in 4:
		var length: int = width if side % 2 == 0 else depth
		var half: float = (depth if side % 2 == 0 else width) * MODULE * 0.5
		var side_basis := Basis(Vector3.UP, side * PI * 0.5)
		for module in length:
			var u: float = (module + 0.5) * MODULE - length * MODULE * 0.5
			# A versão R passa 0,53 m do fim e fecha o canto com a cornija do lado seguinte.
			var piece_name: String = "Cornice_Trim_R" if module == length - 1 else "Cornice_Trim_Center"
			piece(piece_name, base * Transform3D(side_basis, side_basis * Vector3(u, top_y, half)))
	_roof_slab(base, width, depth, top_y)


# Laje de 2x2 m cobrindo `width` x `depth` módulos, centrada.
func _roof_slab(base: Transform3D, width: int, depth: int, y: float) -> void:
	for ix in width:
		for iz in depth:
			var at := Vector3((ix + 0.5) * MODULE - width * MODULE * 0.5, y, (iz + 0.5) * MODULE - depth * MODULE * 0.5)
			piece("Roof_2x2", base * Transform3D(Basis(), at))


func _is_wide(piece_name: String) -> bool:
	return piece_name.begins_with("Brick_Inset") or piece_name in ["Brick_Window_CurvedDouble",
			"Brick_RedWhite_DoubleWindow", "Metal_Window"]


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


# Um material por nome, salvo uma vez em MATERIALS_DIR e usado por todos os prédios.
func _shared_material(source: Material) -> Material:
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


# Vidro opaco, escuro e brilhante (reflete o céu). Transparência custa caro no celular e o
# "interior falso" do pacote é só um plano branco.
func _glass_material() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.11, 0.15, 0.19)
	glass.metallic = 0.7
	glass.roughness = 0.12
	return glass
