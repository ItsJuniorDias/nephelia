class_name ShotEffects
extends Node3D
## Efeitos de TODOS os tiros da partida: rastro, clarão e fumaça do cano, faíscas, poeira e marca
## onde a bala bateu, e sons. As partículas e marcas vêm do `Vfx`.
##
## Só enfeita, não muda o jogo: escuta o MatchReferee e desenha o que ele decidiu. No
## multiplayer cada aparelho roda o seu, a partir dos resultados que o servidor mandar.

@export_group("Rastro")
@export var tracer_color: Color = Color(1.0, 0.86, 0.55, 0.85)
@export_range(0.005, 0.1, 0.005, "suffix:m") var tracer_width: float = 0.02
@export_range(0.02, 0.5, 0.01, "suffix:s") var tracer_duration: float = 0.08

@export_group("Sons")
@export var shot_sound: AudioStream
## Tiro que acerta um personagem.
@export var body_hit_sound: AudioStream
## Tiro que acerta o cenário (sorteia um).
@export var world_hit_sounds: Array[AudioStream] = []

## Tiro se ouve longe (a arena inteira): distância em que o volume começa a cair.
const SHOT_UNIT_SIZE: float = 18.0
## Marcas de tiro no cenário ao mesmo tempo (as mais velhas somem antes da hora).
const MAX_MARKS: int = 40
## Tamanho do clarão no cano visto de fora (m), vezes o `flash_scale` da arma.
const MUZZLE_FLASH_SIZE: float = 0.4
## Fumaça do próprio tiro, na 1ª pessoa (fração do tamanho visto de fora).
const FIRST_PERSON_SMOKE_SIZE: float = 0.35

var _tracer_mesh := BoxMesh.new()
var _marks: Array[MeshInstance3D] = []


func _ready() -> void:
	_tracer_mesh.size = Vector3.ONE
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
	_spawn_muzzle(result, from, data)
	# O tiro é o `shot_sound` daqui (sintetizado), no tom e volume de cada arma; uma arma com
	# tiro próprio na ficha usa o dela.
	if data != null:
		var stream: AudioStream = data.shot_sound if data.shot_sound != null else shot_sound
		_play_at(stream, result.origin, data.shot_volume_db, data.shot_pitch, SHOT_UNIT_SIZE)
	else:
		_play_at(shot_sound, result.origin, 0.0, 1.0, SHOT_UNIT_SIZE)
	if not result.hit:
		return
	_spawn_impacts(result)
	if result.victim != null:
		_play_at(body_hit_sound, result.end_point, 2.0)
	elif not world_hit_sounds.is_empty():
		_play_at(world_hit_sounds.pick_random(), result.end_point, -4.0)


# Clarão (só visto de fora: a 1ª pessoa tem o dela) e fumaça saindo do cano.
func _spawn_muzzle(result: ShotResult, from: Vector3, data: WeaponData) -> void:
	if _is_first_person(result.shooter):
		Vfx.muzzle_smoke(self, from, result.direction, FIRST_PERSON_SMOKE_SIZE)
		return
	var size: float = data.flash_scale if data != null else 1.0
	Vfx.muzzle_flash(self, from, MUZZLE_FLASH_SIZE * size)
	Vfx.muzzle_smoke(self, from, result.direction)


# Cada raio que parou em algo: no cenário, faíscas (só o principal), poeira e marca; num
# personagem, uma nuvem pequena.
func _spawn_impacts(result: ShotResult) -> void:
	var points := PackedVector3Array([result.end_point])
	points.append_array(result.pellet_points)
	var normals: PackedVector3Array = result.ray_normals
	var on_character: Array[bool] = result.ray_hit_character
	if normals.size() != points.size() or on_character.size() != points.size():
		# Resultado sem os dados de cada raio: só o principal, com a normal do acerto.
		points = PackedVector3Array([result.end_point])
		normals = PackedVector3Array([result.hit_normal])
		on_character = [result.victim != null]
	# Nuvem no próprio corpo apareceria colada na câmera de quem levou o tiro: pula.
	var hit_local_player: bool = result.victim != null and result.victim.camera.current
	for i: int in points.size():
		if normals[i] == Vector3.ZERO:
			continue
		if on_character[i]:
			if not hit_local_player:
				Vfx.body_puff(self, points[i], normals[i])
			continue
		if i == 0:
			Vfx.impact_sparks(self, points[i], normals[i])
		Vfx.impact_dust(self, points[i], normals[i], i == 0)
		_leave_mark(points[i], normals[i])


func _leave_mark(at: Vector3, normal: Vector3) -> void:
	while _marks.size() >= MAX_MARKS:
		_marks.pop_front().queue_free()
	var mark: MeshInstance3D = Vfx.bullet_mark(self, at, normal)
	# Some sozinha no fim do tempo dela: sai da lista junto.
	mark.tree_exiting.connect(_marks.erase.bind(mark))
	_marks.append(mark)


## Marcas de tiro no cenário agora (para os testes).
func get_mark_count() -> int:
	return _marks.size()


func _is_first_person(shooter: Character) -> bool:
	var view_model := shooter.camera.get_node_or_null("ViewModel") as ViewModel
	return view_model != null and view_model.is_visible_in_tree()


# O tiro de verdade sai do olho, mas o rastro sai do cano da arma que aparece na tela.
func _visual_origin(result: ShotResult) -> Vector3:
	var shooter: Character = result.shooter
	if _is_first_person(shooter):
		return (shooter.camera.get_node("ViewModel") as ViewModel).muzzle.global_position
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


func _play_at(stream: AudioStream, at: Vector3, volume_db: float, pitch: float = 1.0,
		unit_size: float = 10.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = Sounds.SFX_BUS
	player.unit_size = unit_size
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
