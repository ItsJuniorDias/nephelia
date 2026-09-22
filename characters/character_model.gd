class_name CharacterModel
extends Node3D
## Corpo 3D animado de um personagem (roupa, cabeça, cabelo e chapéu da Quaternius, montados
## pelo Wardrobe a partir da ficha CharacterLook do personagem, + animações da Universal
## Animation Library). Só visual: o Character conta o que está acontecendo e o modelo anima.
##
## Árvore de animação (montada por código em _build_tree):
##   pernas: parado / andar / correr conforme a velocidade; no ar (pulo, trilho), pose de pulo
##   tronco e braços: pose de mirar a pistola, inclinada conforme o olhar (cima/baixo)
##   por cima: tiro e "levou tiro" (só no tronco); morte troca tudo pela queda.
## Pendurado no trilho, o RailGripModifier levanta o braço esquerdo até o trilho.

const ANIMATIONS: AnimationLibrary = preload("res://assets/animations/quaternius_ual/character_animations.res")
## Deste osso para cima o corpo segue a pose de mira (as pernas continuam andando).
const UPPER_BODY_ROOT: StringName = &"spine_01"
## Velocidades (m/s) em que as animações de andar e correr combinam com os passos.
const WALK_SPEED: float = 2.0
const JOG_SPEED: float = 5.0
## Inclinação máxima da mira que a animação de "mirar para cima/baixo" representa.
const AIM_PITCH_RANGE: float = deg_to_rad(60.0)
const HIT_FLASH_ENERGY: float = 1.6
const PROTECTION_COLOR := Color(0.55, 0.8, 1.0)
const PROTECTION_ENERGY: float = 0.45
## Rapidez (por segundo) das trocas de pose: pernas de pulo e braço no trilho.
const AIR_BLEND_SPEED: float = 6.0
const GRIP_BLEND_SPEED: float = 8.0

## Cor de identificação do personagem (tinge o tecido da roupa).
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		if is_node_ready():
			_apply_tint()

var _tree: AnimationTree
## Todos os materiais do corpo (brilho do tiro e da proteção) e só os do tecido (cor).
var _body_materials: Array[BaseMaterial3D] = []
var _cloth_materials: Array[BaseMaterial3D] = []
var _meshes: Array[GeometryInstance3D] = []
var _flash_energy: float = 0.0
var _protected: bool = false
var _airborne: bool = false
var _hanging: bool = false
var _air_amount: float = 0.0
var _grip: RailGripModifier

## Arma na mão direita (criada em código por GunMount) e o suporte dela no corpo.
var gun: MeshInstance3D
var mount: WeaponMount

var skeleton: Skeleton3D
## A ficha de aparência usada para montar o corpo.
var look: CharacterLook


func _ready() -> void:
	# O corpo é montado aqui, com a aparência do personagem (o Character já tem a ficha: as
	# propriedades exportadas chegam antes do _ready dos filhos).
	var owner_character := get_parent() as Character
	look = owner_character.look if owner_character != null and owner_character.look != null \
			else CharacterLook.new()
	var body: Node3D = Wardrobe.build(look)
	add_child(body)
	move_child(body, 0)
	skeleton = body.get_node("Armature/Skeleton3D")
	gun = GunMount.attach(skeleton, WeaponCatalog.default_weapon())
	mount = gun.get_parent() as WeaponMount
	_prepare_materials()
	_apply_tint()
	_build_tree()
	_grip = RailGripModifier.new()
	_grip.name = "RailGrip"
	_grip.influence = 0.0
	_grip.active = false
	skeleton.add_child(_grip)


## Troca a arma que aparece na mão (o Character avisa quando o jogador pega outra).
func set_weapon(data: WeaponData) -> void:
	GunMount.set_weapon(gun, data)


func _process(delta: float) -> void:
	_update_pose_blends(delta)
	if _flash_energy <= 0.0 and not _protected:
		return
	_flash_energy = maxf(_flash_energy - delta * 8.0, 0.0)
	for material: BaseMaterial3D in _body_materials:
		if _flash_energy > 0.0:
			material.emission = Color.WHITE
			material.emission_energy_multiplier = _flash_energy
		elif _protected:
			material.emission = PROTECTION_COLOR
			material.emission_energy_multiplier = PROTECTION_ENERGY
		else:
			material.emission_energy_multiplier = 0.0


## Atualiza pernas e mira. `speed` em m/s (horizontal); `aim_pitch` em radianos (+ = cima);
## `airborne` = fora do chão (pernas na pose de pulo).
func update_motion(speed: float, aim_pitch: float, airborne: bool = false) -> void:
	_airborne = airborne
	_tree.set(&"parameters/locomotion/blend_position", speed)
	_tree.set(&"parameters/aim/blend_position", clampf(aim_pitch / AIM_PITCH_RANGE, -1.0, 1.0))
	# A arma longa fica apoiada no corpo: é ela que sobe e desce com a mira (e os braços vão junto).
	mount.aim_pitch = aim_pitch


## Pendurado num trilho: mão esquerda no trilho e pernas soltas no ar.
func set_hanging(hanging: bool, grip_height: float = 2.0) -> void:
	_hanging = hanging
	_grip.grip_height = grip_height


func is_hanging_pose() -> bool:
	return _grip != null and _grip.influence > 0.0


func play_shoot() -> void:
	_tree.set(&"parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_hit() -> void:
	_tree.set(&"parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_flash_energy = HIT_FLASH_ENERGY


func play_death() -> void:
	_tree.set(&"parameters/life/transition_request", "dead")


func reset_alive() -> void:
	_tree.set(&"parameters/life/transition_request", "alive")


## Brilho azulado enquanto o personagem está com proteção de nascimento.
func set_protected(protected: bool) -> void:
	_protected = protected
	if not protected and _flash_energy <= 0.0:
		for material: BaseMaterial3D in _body_materials:
			material.emission_energy_multiplier = 0.0


func is_shadow_only() -> bool:
	return not _meshes.is_empty() and _meshes[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Só sombra, sem aparecer (o próprio corpo do jogador local).
func set_shadow_only(shadow_only: bool) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if shadow_only
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


# Duplica os materiais (cada personagem com a sua cor) e já liga a emissão com energia 0:
# ligar emissão no meio do jogo trocaria o shader e daria um engasgo. Cores de vértice ficam
# desligadas: o revólver (FBX Wild West Guns) traz cores de vértice que o deixam branco/azul.
func _prepare_materials() -> void:
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		_meshes.append(mesh_instance)
		# A arma some junto com o corpo (jogador local), mas não é tingida: a cor do personagem
		# deixaria o aço cor de pele. E a malha dela muda ao trocar de arma.
		if mesh_instance == gun:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = false
			material.emission_enabled = true
			material.emission_energy_multiplier = 0.0
			mesh_instance.set_surface_override_material(surface, material)
			_body_materials.append(material)
			if Wardrobe.is_cloth(source):
				_cloth_materials.append(material)


# Troca suave das poses de "no ar" (pernas) e "pendurado" (braço esquerdo no trilho).
func _update_pose_blends(delta: float) -> void:
	var air_goal: float = 1.0 if _airborne or _hanging else 0.0
	if _air_amount != air_goal:
		_air_amount = move_toward(_air_amount, air_goal, delta * AIR_BLEND_SPEED)
		_tree.set(&"parameters/air/blend_amount", _air_amount)
	var grip_goal: float = 1.0 if _hanging else 0.0
	if _grip.influence != grip_goal:
		_grip.influence = move_toward(_grip.influence, grip_goal, delta * GRIP_BLEND_SPEED)
		_grip.active = _grip.influence > 0.0


func _apply_tint() -> void:
	# Mistura com branco: tinge o tecido sem esconder a estampa (pele, cabelo e chapéu não).
	# Sem roupa não há tecido, e os bots pintam a pele também: tinge o corpo inteiro, como era
	# antes das roupas.
	if _cloth_materials.is_empty() or (look != null and look.tint_skin):
		for material: BaseMaterial3D in _body_materials:
			material.albedo_color = Color.WHITE.lerp(tint, 0.6)
		return
	var color: Color = Color.WHITE.lerp(tint, 0.5)
	for material: BaseMaterial3D in _cloth_materials:
		material.albedo_color = color


func _build_tree() -> void:
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = JOG_SPEED
	locomotion.add_blend_point(_clip(&"Idle"), 0.0, -1, &"idle")
	locomotion.add_blend_point(_clip(&"Walk"), WALK_SPEED, -1, &"walk")
	locomotion.add_blend_point(_clip(&"Jog_Fwd"), JOG_SPEED, -1, &"jog")

	var aim := AnimationNodeBlendSpace1D.new()
	aim.min_space = -1.0
	aim.max_space = 1.0
	aim.add_blend_point(_clip(&"Pistol_Aim_Down"), -1.0, -1, &"down")
	aim.add_blend_point(_clip(&"Pistol_Aim_Neutral"), 0.0, -1, &"neutral")
	aim.add_blend_point(_clip(&"Pistol_Aim_Up"), 1.0, -1, &"up")

	var upper := AnimationNodeBlend2.new()
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.02
	shoot.fadeout_time = 0.1
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.15
	for node: AnimationNode in [upper, shoot, hit]:
		_filter_upper_body(node)

	var life := AnimationNodeTransition.new()
	life.xfade_time = 0.15
	life.add_input("alive")
	life.add_input("dead")

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node(&"locomotion", locomotion)
	blend_tree.add_node(&"air_clip", _clip(&"Jump"))
	blend_tree.add_node(&"air", AnimationNodeBlend2.new())
	blend_tree.add_node(&"aim", aim)
	blend_tree.add_node(&"upper", upper)
	blend_tree.add_node(&"shoot_clip", _clip(&"Pistol_Shoot"))
	blend_tree.add_node(&"shoot", shoot)
	blend_tree.add_node(&"hit_clip", _clip(&"Hit_Chest"))
	blend_tree.add_node(&"hit", hit)
	blend_tree.add_node(&"death_clip", _clip(&"Death01"))
	blend_tree.add_node(&"life", life)
	blend_tree.connect_node(&"air", 0, &"locomotion")
	blend_tree.connect_node(&"air", 1, &"air_clip")
	blend_tree.connect_node(&"upper", 0, &"air")
	blend_tree.connect_node(&"upper", 1, &"aim")
	blend_tree.connect_node(&"shoot", 0, &"upper")
	blend_tree.connect_node(&"shoot", 1, &"shoot_clip")
	blend_tree.connect_node(&"hit", 0, &"shoot")
	blend_tree.connect_node(&"hit", 1, &"hit_clip")
	blend_tree.connect_node(&"life", 0, &"hit")
	blend_tree.connect_node(&"life", 1, &"death_clip")
	blend_tree.connect_node(&"output", 0, &"life")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.add_animation_library(&"", ANIMATIONS)
	_tree.tree_root = blend_tree
	# As trilhas das animações apontam para "Armature/Skeleton3D:osso", a partir do modelo.
	$Model.add_child(_tree)
	_tree.root_node = NodePath("..")
	_tree.set(&"parameters/upper/blend_amount", 1.0)
	# O nó de transição começa sem estado nenhum (e aí não sai pose): escolhe "vivo" já.
	_tree.set(&"parameters/life/transition_request", "alive")
	_tree.active = true


func _clip(animation_name: StringName) -> AnimationNodeAnimation:
	var clip := AnimationNodeAnimation.new()
	clip.animation = animation_name
	return clip


# Marca, no nó da árvore, os ossos do tronco para cima (spine_01 e todos os "filhos" dele).
func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	var root_bone: int = skeleton.find_bone(UPPER_BODY_ROOT)
	for bone: int in skeleton.get_bone_count():
		var current: int = bone
		while current != -1 and current != root_bone:
			current = skeleton.get_bone_parent(current)
		if current == root_bone:
			node.set_filter_path(NodePath("Armature/Skeleton3D:%s" % skeleton.get_bone_name(bone)), true)
