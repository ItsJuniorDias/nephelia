class_name DebugOverlay
extends CanvasLayer
## Painel de depuração na tela (temporário): mostra o estado da arma na mão do jogador e de um
## bot, para investigar no celular sem precisar do Xcode.
##
## Tirar da cena quando o problema estiver resolvido.

@onready var label: Label = $Label


func _ready() -> void:
	layer = 100


func _process(_delta: float) -> void:
	var lines: Array[String] = []
	lines.append("%s | %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var player: Character = _find_character(false)
	if player != null:
		var view_model: ViewModel = player.camera.get_node_or_null(^"ViewModel") as ViewModel
		if view_model != null:
			lines.append("1a pessoa: " + _describe(view_model.get_node_or_null(
					^"Model/Armature/Skeleton3D/RightHand/Gun") as MeshInstance3D, player.camera))
			lines.append("  braco: " + _describe(_first_mesh(view_model), player.camera))
		else:
			lines.append("1a pessoa: sem ViewModel")
		lines.append("corpo: " + _describe(player.model.gun as MeshInstance3D, player.camera))
	var bot: Character = _find_character(true)
	if bot != null:
		lines.append("bot %s: %s" % [bot.name, _describe(bot.model.gun as MeshInstance3D, player.camera if player else null)])
	label.text = "\n".join(lines)


func _find_character(want_bot: bool) -> Character:
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		var is_bot: bool = character.is_in_group(&"bots")
		if is_bot == want_bot:
			return character
	return null


func _first_mesh(from: Node) -> MeshInstance3D:
	for node: Node in from.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh != null:
			return node as MeshInstance3D
	return null


# Resumo de uma malha: se existe, quantas superfícies, se está visível, tamanho, sombra, material
# e onde está em relação à câmera (frente/lado/altura).
func _describe(mesh_instance: MeshInstance3D, camera: Camera3D) -> String:
	if mesh_instance == null:
		return "no node"
	if mesh_instance.mesh == null:
		return "node ok, MESH NULA"
	var size: Vector3 = mesh_instance.mesh.get_aabb().size
	var material: Material = mesh_instance.get_active_material(0)
	var where: String = "?"
	if camera != null:
		var local: Vector3 = camera.global_basis.inverse() * (mesh_instance.global_position - camera.global_position)
		where = "x=%.2f y=%.2f z=%.2f" % [local.x, local.y, local.z]
	return "surf=%d vis=%s tam=%.2f sombra=%d mat=%s %s" % [mesh_instance.mesh.get_surface_count(),
			mesh_instance.is_visible_in_tree(), size.length(), mesh_instance.cast_shadow,
			material.get_class() if material != null else "nenhum", where]
