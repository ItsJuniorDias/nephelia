class_name SkylineRail
extends Path3D
## Trilho aéreo: um caminho (Path3D) onde os personagens se penduram e deslizam.
## O tubo de latão e os postes são desenhados a partir da curva ao carregar.

const GROUP: StringName = &"skyline_rails"

@export_range(0.02, 0.5, 0.01, "suffix:m") var tube_radius: float = 0.09
## Distância entre os postes (só onde há chão embaixo).
@export_range(4.0, 50.0, 1.0, "suffix:m") var pylon_spacing: float = 14.0
@export var tube_material: Material
@export var pylon_material: Material


func _ready() -> void:
	add_to_group(GROUP)
	_build_tube()
	# As colisões das ilhas (CSG) só existem depois de alguns quadros de física.
	for i in 3:
		await get_tree().physics_frame
	_build_pylons()


func get_length() -> float:
	return curve.get_baked_length()


## Posição ao longo do trilho (em metros desde o começo) mais perto de `world_point`.
func closest_offset(world_point: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_point))


func point_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(offset, 0.0, get_length()), true))


## Direção do trilho (no sentido do começo para o fim) na posição `offset`.
func tangent_at(offset: float) -> Vector3:
	var length: float = get_length()
	var a: Vector3 = point_at(clampf(offset - 0.5, 0.0, length))
	var b: Vector3 = point_at(clampf(offset + 0.5, 0.0, length))
	return (b - a).normalized()


# Tubo: um círculo extrudado ao longo da curva (CSG em modo caminho, sem colisão).
func _build_tube() -> void:
	var tube := CSGPolygon3D.new()
	tube.name = "Tube"
	var circle := PackedVector2Array()
	for i in 8:
		var angle: float = i * TAU / 8.0
		circle.append(Vector2(cos(angle), sin(angle)) * tube_radius)
	tube.polygon = circle
	tube.mode = CSGPolygon3D.MODE_PATH
	tube.path_node = NodePath("..")
	tube.path_local = true
	tube.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	tube.path_interval = 0.5
	tube.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	tube.smooth_faces = true
	tube.material = tube_material
	add_child(tube)


# Postes do trilho até o chão, a cada `pylon_spacing` metros (só se houver chão por perto).
func _build_pylons() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var offset: float = pylon_spacing * 0.5
	while offset < get_length():
		var top: Vector3 = point_at(offset) + Vector3.UP * 0.3
		var query := PhysicsRayQueryParameters3D.create(top + Vector3.DOWN * 2.6, top + Vector3.DOWN * 20.0)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty() and not (hit.collider is Character):
			var height: float = top.y - hit.position.y
			var pylon := MeshInstance3D.new()
			pylon.name = "Pylon"
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.12
			mesh.bottom_radius = 0.18
			mesh.height = height
			mesh.radial_segments = 8
			pylon.mesh = mesh
			pylon.material_override = pylon_material
			add_child(pylon)
			pylon.global_position = Vector3(top.x, hit.position.y + height * 0.5, top.z)
		offset += pylon_spacing
