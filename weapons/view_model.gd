class_name ViewModel
extends Node3D
## Arma vista em primeira pessoa, só para o jogador local. É só visual: coice, balanço ao
## andar, recarga e clarão. O tiro de verdade sai do olho e quem decide é o MatchReferee.

@export_group("Coice")
## Quanto a arma sobe e recua a cada tiro.
@export var recoil_offset: Vector3 = Vector3(0.0, 0.025, 0.09)
@export_range(0.0, 45.0, 0.5, "suffix:°") var recoil_pitch_degrees: float = 14.0
## Velocidade de volta ao lugar depois do coice.
@export_range(1.0, 40.0, 0.5) var recover_speed: float = 12.0

@export_group("Balanço ao andar")
@export_range(0.0, 0.05, 0.001, "suffix:m") var bob_amount: float = 0.012
@export_range(1.0, 20.0, 0.5) var bob_frequency: float = 10.0

@export_group("Recarga")
@export_range(0.0, 0.3, 0.01, "suffix:m") var reload_drop: float = 0.12
@export_range(0.0, 90.0, 1.0, "suffix:°") var reload_roll_degrees: float = 40.0
@export var reload_start_sound: AudioStream
@export var reload_end_sound: AudioStream

@export_group("Clarão")
@export_range(0.01, 0.2, 0.01, "suffix:s") var flash_duration: float = 0.05

var character: Character
var weapon: Weapon

var _rest_position: Vector3
var _kick: float = 0.0
var _bob_time: float = 0.0
var _bob_weight: float = 0.0
var _flash_timer: float = 0.0

@onready var model: Node3D = $Model
@onready var muzzle: Marker3D = $Model/Muzzle
@onready var flash: MeshInstance3D = $Model/Muzzle/Flash
@onready var audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	_rest_position = position
	_prepare_meshes()


## Chamado pelo HumanController: liga a arma na lógica de tiro do personagem.
func setup(for_character: Character, for_weapon: Weapon) -> void:
	character = for_character
	weapon = for_weapon
	weapon.fired.connect(_on_fired)
	weapon.reload_started.connect(_play.bind(reload_start_sound))
	weapon.reload_finished.connect(_play.bind(reload_end_sound))


func _process(delta: float) -> void:
	if character == null:
		return
	# Volta do coice amortecida (independe do FPS).
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-recover_speed * delta))

	# Balanço só andando no chão; entra e sai suave.
	var speed: float = Vector2(character.velocity.x, character.velocity.z).length()
	var walking: bool = character.is_on_floor() and speed > 0.5
	_bob_weight = move_toward(_bob_weight, 1.0 if walking else 0.0, delta * 4.0)
	_bob_time += delta * bob_frequency * clampf(speed / character.walk_speed, 0.0, 1.5)
	var bob := Vector3(sin(_bob_time) * bob_amount, -absf(cos(_bob_time)) * bob_amount, 0.0) * _bob_weight

	# Recarga: a arma desce e tomba, depois volta (curva em "sino").
	var reload_curve: float = sin(weapon.get_reload_progress() * PI)

	position = _rest_position + bob + recoil_offset * _kick + Vector3.DOWN * reload_drop * reload_curve
	rotation = Vector3(deg_to_rad(recoil_pitch_degrees) * _kick, 0.0, deg_to_rad(reload_roll_degrees) * reload_curve)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		flash.visible = _flash_timer > 0.0


func _on_fired(_result: ShotResult) -> void:
	_kick = 1.0
	# Tamanho um pouco diferente a cada tiro, para o clarão não parecer carimbado.
	flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	flash.visible = true
	_flash_timer = flash_duration


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	audio.stream = stream
	audio.play()


# A arma não faz nem recebe sombra (senão fica dentro da sombra do próprio corpo do jogador e
# só pega a luz azul do céu) e é desenhada "mais perto" da câmera (z_clip_scale) para não
# atravessar paredes. Os FBX desse pacote trazem cores de vértice azuladas: desligamos o uso
# delas e damos cara de aço às partes cinzas.
func _prepare_meshes() -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = false
			material.disable_receive_shadows = true
			if material.albedo_color.s < 0.15:
				material.metallic = 0.6
				material.roughness = 0.4
			material.use_z_clip_scale = true
			material.z_clip_scale = 0.3
			mesh_instance.set_surface_override_material(surface, material)
