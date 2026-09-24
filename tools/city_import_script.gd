@tool
extends EditorScenePostImport
## Script de importação das peças do Downtown City MegaKit (`assets/models/city/downtown/*.gltf`):
## troca o material de cada superfície pelo material do projeto com o mesmo nome
## (`assets/materials/city/<nome>.tres`: o shader do pacote com desgaste nas quinas e sujeira, ou o
## nosso vidro opaco). As 5 variações de sala atrás da janela (MI_FakeInterior, _1 a _4) viram uma
## só: o sorteio de cada janela vai na cor do vértice (ver CityKit e fake_interior.gdshader).
## Baseado no script de importação que vem no pacote (Cat Prisbrey, CC0).

const FOLDER := "res://assets/materials/city/"


func _post_import(scene: Node) -> Object:
	_replace_materials(scene)
	return scene


func _replace_materials(node: Node) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for surface in instance.mesh.get_surface_count():
			var material: Material = instance.mesh.surface_get_material(surface)
			if material == null:
				continue
			var material_name: String = material.resource_name
			if material_name.begins_with("MI_FakeInterior"):
				material_name = "MI_FakeInterior"
			var path: String = FOLDER + material_name + ".tres"
			if ResourceLoader.exists(path):
				instance.mesh.surface_set_material(surface, load(path))
	for child: Node in node.get_children():
		_replace_materials(child)
