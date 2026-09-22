class_name ShotEffects
extends Node3D
## Efeitos de TODOS os tiros da partida: rastro, faíscas e sons.
##
## Só enfeita, não muda o jogo: escuta o MatchReferee e desenha o que ele decidiu. No
## multiplayer cada aparelho roda o seu, a partir dos resultados que o servidor mandar.

@export_group("Rastro")
@export var tracer_color: Color = Color(1.0, 0.86, 0.55, 0.85)
@export_range(0.005, 0.1, 0.005, "suffix:m") var tracer_width: float = 0.02
@export_range(0.02, 0.5, 0.01, "suffix:s") var tracer_duration: float = 0.08

@export_group("Faíscas")
@export var spark_texture: Texture2D
@export var spark_color: Color = Color(1.0, 0.75, 0.35)

@export_group("Sons")
@export var shot_sound: AudioStream
## Tiro que acerta um personagem.
@export var body_hit_sound: AudioStream
## Tiro que acerta o cenário (sorteia um).
@export var world_hit_sounds: Array[AudioStream] = []

var _tracer_mesh := BoxMesh.new()
var _spark_mesh := QuadMesh.new()


func _ready() -> void:
	_tracer_mesh.size = Vector3.ONE
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_material.vertex_color_use_as_albedo = true
	spark_material.albedo_texture = spark_texture
	_spark_mesh.material = spark_material
	# O juiz pode ficar pronto depois de nós: conectamos no fim do quadro.
	_connect_to_referee.call_deferred()


func _connect_to_referee() -> void:
	var referee: MatchReferee = MatchReferee.find(self)
	if referee != null:
		referee.shot_resolved.connect(_on_shot_resolved)


func _on_shot_resolved(result: ShotResult) -> void:
	var from: Vector3 = _visual_origin(result)
	_spawn_tracer(from, result.end_point)
	# Espingarda: um rastro para cada chumbo (é o que mostra o leque do tiro).
	for point: Vector3 in result.pellet_points:
		_spawn_tracer(from, point)
	var data: WeaponData = result.weapon.data if result.weapon != null else null
	if data != null:
		_play_at(shot_sound, result.origin, data.shot_volume_db, data.shot_pitch)
	else:
		_play_at(shot_sound, result.origin, 0.0)
	if not result.hit:
		return
	# Faíscas no próprio corpo apareceriam coladas na câmera de quem levou o tiro: pula.
	var hit_local_player: bool = result.victim != null and result.victim.camera.current
	if not hit_local_player:
		_spawn_sparks(result.end_point, result.hit_normal)
	if result.victim != null:
		_play_at(body_hit_sound, result.end_point, 2.0)
	elif not world_hit_sounds.is_empty():
		_play_at(world_hit_sounds.pick_random(), result.end_point, -4.0)


# O tiro de verdade sai do olho, mas o rastro sai do cano da arma que aparece na tela.
func _visual_origin(result: ShotResult) -> Vector3:
	var shooter: Character = result.shooter
	var view_model := shooter.camera.get_node_or_null("ViewModel") as ViewModel
	if view_model != null and view_model.is_visible_in_tree():
		return view_model.muzzle.global_position
	# Para os outros personagens: a ponta do cano da arma na mão do modelo.
	return shooter.model.gun.global_transform * _barrel_tip(result)


func _barrel_tip(result: ShotResult) -> Vector3:
	if result.weapon != null and result.weapon.data != null:
		return result.weapon.data.barrel_tip
	return GunMount.BARREL_TIP


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = tracer_color

	var tracer := MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	tracer.material_override = material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	tracer.look_at_from_position((from + to) * 0.5, to, up)
	tracer.scale = Vector3(tracer_width, tracer_width, length)

	var tween := tracer.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, tracer_duration)
	tween.tween_callback(tracer.queue_free)


func _spawn_sparks(at: Vector3, normal: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.mesh = _spark_mesh
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 40.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0.0, -9.8, 0.0)
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.14
	sparks.color = spark_color
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	# A "direção para cima" das faíscas aponta para fora da superfície atingida.
	sparks.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal.normalized())), at + normal * 0.02)
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true


func _play_at(stream: AudioStream, at: Vector3, volume_db: float, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.93, 1.07)
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
