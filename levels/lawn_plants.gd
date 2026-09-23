class_name LawnPlants
extends MultiMeshInstance3D
## Várias cópias de uma planta (tufo de capim, flor) espalhadas pelo gramado, numa chamada de
## desenho só. O MultiMesh é montado ao abrir a arena a partir de `transforms`: gerado sem janela
## (tools/build_skyplaza.gd), o Godot não guarda os dados de um MultiMesh na cena e as plantas
## iam todas para a origem.

## A planta (malha do Nature Kit, com o material dela).
@export var plant_mesh: Mesh
## Uma planta a cada 12 números: as três linhas de um Transform3D (base x/y/z e origem, por linha).
@export var transforms: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var instances: int = transforms.size() / 12
	var built := MultiMesh.new()
	built.transform_format = MultiMesh.TRANSFORM_3D
	built.mesh = plant_mesh
	built.instance_count = instances
	for i in instances:
		built.set_instance_transform(i, transform_at(i))
	multimesh = built


## Número de plantas.
func get_count() -> int:
	return transforms.size() / 12


## Onde fica a planta `index` (espaço deste nó).
func transform_at(index: int) -> Transform3D:
	var f: PackedFloat32Array = transforms.slice(index * 12, index * 12 + 12)
	return Transform3D(Vector3(f[0], f[4], f[8]), Vector3(f[1], f[5], f[9]), Vector3(f[2], f[6], f[10]),
			Vector3(f[3], f[7], f[11]))


## Guarda uma lista de posições no formato de `transforms`.
static func pack(list: Array) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for t: Transform3D in list:
		packed.append_array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x,
				t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
				t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z])
	return packed
