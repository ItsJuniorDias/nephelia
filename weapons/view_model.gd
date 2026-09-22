class_name ViewModel
extends Node3D
## Braços do jogador com a arma, vistos em primeira pessoa (só do jogador local).
##
## Usa o mesmo corpo e as mesmas animações de pistola do personagem (parado, tiro e recarga),
## com a cabeça e as pernas encolhidas pelo HiddenBonesModifier: o jogador vê só os braços.
## Por cima da animação vêm o coice, o balanço ao andar e o clarão do cano. É só visual: o tiro
## de verdade sai do olho e quem decide o acerto é o MatchReferee.

const ANIMATIONS: AnimationLibrary = preload("res://assets/animations/quaternius_ual/character_animations.res")
## Ponta do cano no espaço do modelo do Colt (medido nos vértices do FBX).
const BARREL_TIP := Vector3(0.0005, 0.1477, -0.19)

@export_group("Coice")
## Quanto a arma sobe e recua a cada tiro.
@export var recoil_offset: Vector3 = Vector3(0.0, 0.015, 0.06)
@export_range(0.0, 45.0, 0.5, "suffix:°") var recoil_pitch_degrees: float = 8.0
## Velocidade de volta ao lugar depois do coice.
@export_range(1.0, 40.0, 0.5) var recover_speed: float = 12.0

@export_group("Balanço ao andar")
@export_range(0.0, 0.05, 0.001, "suffix:m") var bob_amount: float = 0.012
@export_range(1.0, 20.0, 0.5) var bob_frequency: float = 10.0

@export_group("Sons")
@export var reload_start_sound: AudioStream
@export var reload_end_sound: AudioStream

@export_group("Clarão")
@export_range(0.01, 0.2, 0.01, "suffix:s") var flash_duration: float = 0.05

var character: Character
var weapon: Weapon

var _tree: AnimationTree
var _rest_position: Vector3
var _kick: float = 0.0
var _bob_time: float = 0.0
var _bob_weight: float = 0.0
var _flash_timer: float = 0.0

@onready var model: Node3D = $Model
@onready var skeleton: Skeleton3D = $Model/Armature/Skeleton3D
@onready var muzzle: Marker3D = $Model/Armature/Skeleton3D/RightHand/Gun/Muzzle
@onready var flash: MeshInstance3D = $Model/Armature/Skeleton3D/RightHand/Gun/Muzzle/Flash
@onready var audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	_rest_position = position
	_prepare_meshes()
	_hide_bones()
	_build_tree()


## Chamado pelo HumanController: liga os braços na lógica de tiro do personagem.
func setup(for_character: Character, for_weapon: Weapon) -> void:
	character = for_character
	weapon = for_weapon
	weapon.fired.connect(_on_fired)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_play.bind(reload_end_sound))
	# As animações acompanham o ritmo da arma (tiro antes do próximo, recarga no tempo dela).
	_tree.set(&"parameters/shoot_speed/scale",
			ANIMATIONS.get_animation(&"Pistol_Shoot").length / maxf(weapon.fire_interval, 0.05))
	_tree.set(&"parameters/reload_speed/scale",
			ANIMATIONS.get_animation(&"Pistol_Reload").length / maxf(weapon.reload_time, 0.1))


func _process(delta: float) -> void:
	if character == null:
		return
	# Volta do coice amortecida (independe do FPS).
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-recover_speed * delta))

	# Balanço só andando no chão; entra e sai suave.
	var speed: float = Vector2(character.velocity.x, character.velocity.z).length()
	var walking: bool = character.is_grounded() and speed > 0.5
	_bob_weight = move_toward(_bob_weight, 1.0 if walking else 0.0, delta * 4.0)
	_bob_time += delta * bob_frequency * clampf(speed / character.walk_speed, 0.0, 1.5)
	var bob := Vector3(sin(_bob_time) * bob_amount, -absf(cos(_bob_time)) * bob_amount, 0.0) * _bob_weight

	position = _rest_position + bob + recoil_offset * _kick
	rotation = Vector3(deg_to_rad(recoil_pitch_degrees) * _kick, 0.0, 0.0)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		flash.visible = _flash_timer > 0.0


func _on_fired(_result: ShotResult) -> void:
	_tree.set(&"parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_kick = 1.0
	# Tamanho um pouco diferente a cada tiro, para o clarão não parecer carimbado.
	flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	flash.visible = true
	_flash_timer = flash_duration


func _on_reload_started() -> void:
	_tree.set(&"parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_play(reload_start_sound)


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	audio.stream = stream
	audio.play()


# Parado, tiro e recarga: os dois últimos entram por cima do parado e voltam sozinhos.
func _build_tree() -> void:
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node(&"idle", _clip(&"Pistol_Idle"))
	blend_tree.add_node(&"shoot_clip", _clip(&"Pistol_Shoot"))
	blend_tree.add_node(&"shoot_speed", AnimationNodeTimeScale.new())
	blend_tree.add_node(&"reload_clip", _clip(&"Pistol_Reload"))
	blend_tree.add_node(&"reload_speed", AnimationNodeTimeScale.new())
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.02
	shoot.fadeout_time = 0.12
	blend_tree.add_node(&"shoot", shoot)
	var reload := AnimationNodeOneShot.new()
	reload.fadein_time = 0.12
	reload.fadeout_time = 0.25
	blend_tree.add_node(&"reload", reload)
	blend_tree.connect_node(&"shoot_speed", 0, &"shoot_clip")
	blend_tree.connect_node(&"reload_speed", 0, &"reload_clip")
	blend_tree.connect_node(&"shoot", 0, &"idle")
	blend_tree.connect_node(&"shoot", 1, &"shoot_speed")
	blend_tree.connect_node(&"reload", 0, &"shoot")
	blend_tree.connect_node(&"reload", 1, &"reload_speed")
	blend_tree.connect_node(&"output", 0, &"reload")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.add_animation_library(&"", ANIMATIONS)
	_tree.tree_root = blend_tree
	# As trilhas apontam para "Armature/Skeleton3D:osso", a partir do modelo.
	model.add_child(_tree)
	_tree.root_node = NodePath("..")
	_tree.active = true


func _clip(animation_name: StringName) -> AnimationNodeAnimation:
	var clip := AnimationNodeAnimation.new()
	clip.animation = animation_name
	return clip


# Em primeira pessoa a cabeça e as pernas atrapalhariam a câmera: somem.
func _hide_bones() -> void:
	var hidden := HiddenBonesModifier.new()
	hidden.name = "HiddenBones"
	skeleton.add_child(hidden)


# Os braços e a arma não fazem nem recebem sombra (senão ficam na sombra do próprio corpo e
# puxam o azul do céu) e são desenhados "mais perto" da câmera (z_clip_scale) para não
# atravessar paredes. Cada superfície ganha um material novo e simples: o do personagem usa
# textura ORM (metal e rugosidade juntos), que deixaria a pele com brilho de plástico tão perto
# da câmera, e os FBX das armas trazem cores de vértice azuladas.
func _prepare_meshes() -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			mesh_instance.set_surface_override_material(surface, _view_material(source))


func _view_material(source: BaseMaterial3D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = source.albedo_color
	material.albedo_texture = source.albedo_texture
	if source.normal_enabled:
		material.normal_enabled = true
		material.normal_texture = source.normal_texture
		material.normal_scale = source.normal_scale
	material.disable_receive_shadows = true
	material.use_z_clip_scale = true
	material.z_clip_scale = 0.3
	if source.albedo_color.s < 0.15 and source.albedo_texture == null:
		# Partes cinzas sem textura (a arma): aço escuro, sem virar espelho do céu.
		material.albedo_color = source.albedo_color.darkened(0.5)
		material.metallic = 0.1
		material.roughness = 0.6
	else:
		# Pele e roupa: foscas.
		material.metallic = 0.0
		material.roughness = 0.85
	return material
