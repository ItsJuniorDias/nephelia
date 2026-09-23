extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var level: Node3D = (load("res://levels/skyplaza/skyplaza.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 3: await physics_frame
	for who: Character in [get_nodes_in_group(&"bots")[0], level.get_node("Player")]:
		var skeleton: Skeleton3D = who.model.skeleton
		for mesh_name: String in ["Body", "Male_Peasant_Body", "Hair", "Hat"]:
			var mi := skeleton.get_node_or_null(mesh_name) as MeshInstance3D
			if mi == null:
				continue
			var skin: Skin = mi.skin
			var target := mi.get_node_or_null(mi.skeleton)
			var binds: PackedStringArray = []
			for b in mini(skin.get_bind_count(), 8):
				binds.append("%s/%d" % [skin.get_bind_name(b), skin.get_bind_bone(b)])
			# Pesos dos vértices da cabeça (acima de 1,45 m).
			var totals: Dictionary = {}
			var count: int = 0
			for s in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if bones.is_empty():
					continue
				var per: int = bones.size() / verts.size()
				for v in verts.size():
					if verts[v].y < 1.45:
						continue
					count += 1
					for k in per:
						var w: float = weights[v * per + k]
						if w > 0.0:
							var bi: int = bones[v * per + k]
							var nm: String = str(skin.get_bind_name(bi)) if bi < skin.get_bind_count() else "?%d" % bi
							totals[nm] = totals.get(nm, 0.0) + w
			print("%s %s: skeleton_path=%s ok=%s binds=%d %s | head verts=%d weights=%s" % [who.name, mesh_name, mi.skeleton, target == skeleton, skin.get_bind_count(), binds, count, totals])
	quit()
