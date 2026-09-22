class_name ViewModel
extends Node3D
## Braços do jogador com a arma, vistos em primeira pessoa (só do jogador local).
##
## Usa o mesmo corpo e as mesmas animações de pistola do personagem (parado, tiro e recarga),
## com a cabeça e as pernas encolhidas pelo HiddenBonesModifier: o jogador vê só os braços.
## Por cima da animação vêm o coice, o balanço ao andar e o clarão do cano. É só visual: o tiro
## de verdade sai do olho e quem decide o acerto é o MatchReferee.

const ANIMATIONS: AnimationLibrary = preload("res://assets/animations/quaternius_ual/character_animations.res")
const FLASH_TEXTURE: Texture2D = preload("res://assets/vfx/kenney/star_09.png")
## Corpo virado para a frente da câmera, com o osso da cabeça na altura do olho.
const MODEL_OFFSET := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -1.5, 0.0))

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

@export_group("Mira")
## Distância em que o cano cruza o centro da tela (é lá que o tiro vai).
@export_range(2.0, 50.0, 0.5, "suffix:m") var converge_distance: float = 12.0
## Na recarga das armas longas a arma gira e abaixa (ver WeaponMount): em 1ª pessoa os braços
## sobem este tanto, senão ela sairia da tela.
@export_range(0.0, 45.0, 0.5, "suffix:°") var reload_lift_degrees: float = 24.0

var character: Character
var weapon: Weapon

var _tree: AnimationTree
var _rest_position: Vector3
var _kick: float = 0.0
var _bob_time: float = 0.0
var _bob_weight: float = 0.0
var _flash_timer: float = 0.0
## Giro que faz o cano apontar para a mira, em volta da pegada (`_aim_pivot`).
var _aim_fix := Quaternion.IDENTITY
var _aim_pivot := Vector3.ZERO
## Quadros em que a correção vai direto ao valor novo (logo depois de trocar de arma).
var _snap_frames: int = 3

## Arma, ponta do cano e clarão (criados em código, como no corpo do personagem).
var gun: MeshInstance3D
var muzzle: Marker3D
var flash: MeshInstance3D

## Corpo (o mesmo do personagem, com a roupa dele), montado em código no _ready.
var model: Node3D
var skeleton: Skeleton3D

@onready var audio: AudioStreamPlayer = $Audio


func _ready() -> void:
	_rest_position = position
	_build_body()
	_build_gun()
	_prepare_meshes()
	_hide_bones()
	_build_tree()


# O mesmo corpo do personagem dono desta câmera (a manga da camisa aparece nos braços), girado
# para olhar para a frente da câmera e com a cabeça logo abaixo dela.
func _build_body() -> void:
	var look: CharacterLook = null
	var node: Node = get_parent()
	while node != null and look == null:
		if node is Character:
			look = (node as Character).look
			break
		node = node.get_parent()
	model = Wardrobe.build(look if look != null else CharacterLook.new())
	model.transform = MODEL_OFFSET
	add_child(model)
	move_child(model, 0)
	skeleton = model.get_node("Armature/Skeleton3D")


# Arma na mão, marcador da ponta do cano e o clarão do tiro.
func _build_gun() -> void:
	gun = GunMount.attach(skeleton, WeaponCatalog.default_weapon())
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = GunMount.BARREL_TIP
	gun.add_child(muzzle)
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_material.no_depth_test = true
	flash_material.albedo_color = Color(1.0, 0.86, 0.55)
	flash_material.albedo_texture = FLASH_TEXTURE
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = flash_material
	flash = MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)


## Chamado pelo HumanController: liga os braços na lógica de tiro do personagem.
func setup(for_character: Character, for_weapon: Weapon) -> void:
	character = for_character
	weapon = for_weapon
	weapon.fired.connect(_on_fired)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_play.bind(reload_end_sound))
	weapon.weapon_changed.connect(_show_weapon)
	# O suporte faz o movimento da recarga das armas longas; o coice aqui são os braços inteiros.
	var mount := gun.get_parent() as WeaponMount
	mount.animate_kick = false
	mount.watch(weapon)
	_show_weapon(weapon.data)


## Mostra a arma que o jogador está segurando agora (item pego ou munição no fim).
func _show_weapon(data: WeaponData) -> void:
	GunMount.set_weapon(gun, data)
	_style_mesh(gun)
	muzzle.position = data.barrel_tip
	# As animações acompanham o ritmo da arma (tiro antes do próximo, recarga no tempo dela).
	_tree.set(&"parameters/shoot_speed/scale",
			ANIMATIONS.get_animation(&"Pistol_Shoot").length / maxf(data.fire_interval, 0.05))
	_tree.set(&"parameters/reload_speed/scale",
			ANIMATIONS.get_animation(&"Pistol_Reload").length / maxf(data.reload_time, 0.1))
	_snap_frames = 3


func _process(delta: float) -> void:
	if character == null:
		return
	_update_aim_fix(delta)
	# Volta do coice amortecida (independe do FPS).
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-recover_speed * delta))

	# Balanço só andando no chão; entra e sai suave.
	var speed: float = Vector2(character.velocity.x, character.velocity.z).length()
	var walking: bool = character.is_grounded() and speed > 0.5
	_bob_weight = move_toward(_bob_weight, 1.0 if walking else 0.0, delta * 4.0)
	_bob_time += delta * bob_frequency * clampf(speed / character.walk_speed, 0.0, 1.5)
	var bob := Vector3(sin(_bob_time) * bob_amount, -absf(cos(_bob_time)) * bob_amount, 0.0) * _bob_weight

	# A correção da mira gira tudo em volta do olho (como baixar um pouco a cabeça); o coice gira
	# em volta da pegada.
	var kick_turn := Basis(Vector3.RIGHT, deg_to_rad(recoil_pitch_degrees) * _kick)
	var lift := Basis(Vector3.RIGHT, deg_to_rad(reload_lift_degrees) * _reload_lift())
	transform = Transform3D(lift * Basis(_aim_fix), bob + recoil_offset * _kick) \
			* Transform3D(Basis.IDENTITY, _rest_position + _aim_pivot) \
			* Transform3D(kick_turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -_aim_pivot)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		flash.visible = _flash_timer > 0.0


# Em 1ª pessoa a arma longa fica abaixo e ao lado do olho, apontada um pouco para dentro (senão
# a mão esquerda não alcança a telha): do jeito que o corpo a segura ela não passaria pelo centro
# da tela. Aqui os braços giram em volta do olho até o cano cruzar a mira a `converge_distance`. A conta
# usa a arma vista deste nó, então a própria correção não entra nela. Na recarga a animação
# mexe a arma: a correção fica parada.
func _update_aim_fix(delta: float) -> void:
	if gun == null or weapon == null or weapon.data == null:
		return
	if weapon.is_reloading and _snap_frames <= 0:
		return
	# O revólver fica como a animação manda (é a versão aprovada): sem correção.
	if not weapon.data.is_two_handed():
		_aim_fix = Quaternion.IDENTITY
		_aim_pivot = Vector3.ZERO
		_snap_frames = 0
		return
	var gun_local: Transform3D = global_transform.affine_inverse() * gun.global_transform
	var tip: Vector3 = _rest_position + gun_local * weapon.data.barrel_tip
	var barrel: Vector3 = (gun_local.basis * Vector3.FORWARD).normalized()
	if barrel.length_squared() < 0.5:
		return
	# Girar muda um pouco onde fica a ponta do cano: três voltas bastam para acertar.
	var goal := Vector3(0.0, 0.0, -converge_distance)
	var target := Quaternion.IDENTITY
	for i in 3:
		var wanted: Vector3 = (goal - target * tip).normalized()
		if barrel.dot(wanted) < -0.99:
			return
		target = Quaternion(barrel, wanted)
	_aim_pivot = gun_local.origin
	if _snap_frames > 0:
		_snap_frames -= 1
		_aim_fix = target
	else:
		_aim_fix = _aim_fix.slerp(target, 1.0 - exp(-6.0 * delta))


# 0 fora da recarga, 1 no meio dela (só nas armas longas: o revólver usa a animação).
func _reload_lift() -> float:
	if weapon == null or weapon.data == null or not weapon.data.is_two_handed() or not weapon.is_reloading:
		return 0.0
	return sin(PI * weapon.get_reload_progress())


## Quanto o cano está fora da mira agora, em graus (0 = passa pelo centro da tela a
## `converge_distance`). Serve para os testes.
func get_aim_error_degrees() -> float:
	var tip: Vector3 = get_parent_node_3d().global_transform.affine_inverse() * muzzle.global_position
	var barrel: Vector3 = get_parent_node_3d().global_transform.basis.inverse() * (gun.global_transform.basis * Vector3.FORWARD)
	var wanted: Vector3 = Vector3(0.0, 0.0, -converge_distance) - tip
	return rad_to_deg(barrel.normalized().angle_to(wanted.normalized()))


func _on_fired(_result: ShotResult) -> void:
	_tree.set(&"parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	# Armas maiores coiceiam mais e têm clarão maior.
	_kick = weapon.data.recoil if weapon.data != null else 1.0
	var flash_size: float = weapon.data.flash_scale if weapon.data != null else 1.0
	# Tamanho um pouco diferente a cada tiro, para o clarão não parecer carimbado.
	flash.scale = Vector3.ONE * randf_range(0.8, 1.25) * flash_size
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
		_style_mesh(node as MeshInstance3D)


# Trocar de arma troca a malha, e com ela a lista de materiais: o tratamento é refeito.
func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface: int in mesh_instance.mesh.get_surface_count():
		mesh_instance.set_surface_override_material(surface, null)
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
