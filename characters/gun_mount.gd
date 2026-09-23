class_name GunMount
extends RefCounted
## Monta a arma do personagem em código: na mão direita (revólver) ou apoiada no peito com as
## duas mãos nela (rifle e espingarda).
##
## Antes a arma era um nó guardado dentro da cena do modelo (filho de um nó que segue o osso).
## No build do iPhone esses nós não existiam e ninguém aparecia armado, embora no Mac
## funcionasse. Criando na hora, a montagem é a mesma para o corpo e para a 1ª pessoa e não
## depende de nós salvos dentro de uma cena instanciada.
##
## As animações são todas de pistola. Numa arma longa isso não serve: ela fica apoiada no peito
## (que acompanha a mira para cima e para baixo) e cada braço é levado até o ponto dela pelo
## `characters/weapon_grip_modifier.gd`.

## Ponta do cano do revólver, para quem ainda não tem a ficha em mãos.
const BARREL_TIP := Vector3(0.0005, 0.1477, -0.19)
const HAND_BONE: StringName = &"hand_r"
## Nomes dos nós criados aqui (para achar de novo ao trocar de arma).
const RIGHT_GRIP := "RightGrip"
const FORE_GRIP := "ForeGrip"
const RIGHT_ARM_IK := "RightArmGrip"
const LEFT_ARM_IK := "LeftArmGrip"


## Cria o suporte que segue o osso, a arma nele e a IK dos dois braços; devolve o nó da arma.
static func attach(skeleton: Skeleton3D, data: WeaponData = null) -> MeshInstance3D:
	var mount := WeaponMount.new()
	mount.name = "WeaponMount"
	mount.bone_name = HAND_BONE
	skeleton.add_child(mount)
	var gun := MeshInstance3D.new()
	gun.name = "Gun"
	mount.add_child(gun)
	# Pontos da arma onde cada mão segura (só as armas longas usam).
	var right_grip := _marker(gun, RIGHT_GRIP)
	var fore_grip := _marker(gun, FORE_GRIP)
	# O suporte se atualiza na etapa do esqueleto, antes das mãos irem até a arma.
	var sync := WeaponMountSync.new()
	sync.name = "WeaponMountSync"
	sync.mount = mount
	skeleton.add_child(sync)
	_grip_ik(skeleton, RIGHT_ARM_IK, "r", right_grip, Vector3(-0.6, -1.0, -0.2))
	var left_ik: WeaponGripModifier = _grip_ik(skeleton, LEFT_ARM_IK, "l", fore_grip, Vector3(0.5, -1.0, -0.3))
	# A mão de apoio da animação de pistola é aberta: na telha ela fecha como a direita.
	left_ik.copy_fingers_from = &"hand_r"
	set_weapon(gun, data if data != null else WeaponCatalog.default_weapon())
	return gun


## Troca a arma: malha, lugar dela no corpo e as mãos no lugar certo dessa arma.
## `first_person`: braços da 1ª pessoa (arma longa na posição baixa, `WeaponData.view_mount`).
static func set_weapon(gun: MeshInstance3D, data: WeaponData, first_person: bool = false) -> void:
	gun.mesh = data.mesh
	var mount := gun.get_parent() as WeaponMount
	if mount == null:
		return
	var skeleton := mount.get_parent() as Skeleton3D
	if skeleton == null:
		return
	# Arma longa: apoiada no corpo (osso nenhum), com as duas mãos indo até ela.
	if data.is_two_handed():
		# O coice e a recarga giram a arma entre as duas mãos.
		var at: Transform3D = data.view_mount if first_person and not data.view_mount.is_equal_approx(Transform3D.IDENTITY) \
				else data.chest_mount
		mount.follow(&"", at, (data.right_grip.origin + data.fore_grip.origin) * 0.5)
	else:
		mount.follow(HAND_BONE, data.in_hand)
	var right_grip := gun.get_node_or_null(RIGHT_GRIP) as Marker3D
	if right_grip != null:
		right_grip.transform = data.right_grip
	var fore_grip := gun.get_node_or_null(FORE_GRIP) as Marker3D
	if fore_grip != null:
		fore_grip.transform = data.fore_grip
	# O revólver fica como a animação de pistola manda (as duas mãos juntas no cabo); só as
	# armas longas levam os braços até a arma.
	for ik_name: String in [RIGHT_ARM_IK, LEFT_ARM_IK]:
		var ik := skeleton.get_node_or_null(ik_name) as WeaponGripModifier
		if ik != null:
			ik.active = data.is_two_handed()


static func _marker(gun: MeshInstance3D, marker_name: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	gun.add_child(marker)
	return marker


static func _grip_ik(skeleton: Skeleton3D, ik_name: String, side: String, target: Node3D,
		elbow: Vector3) -> WeaponGripModifier:
	var ik := WeaponGripModifier.new()
	ik.name = ik_name
	ik.upper_arm_bone = StringName("upperarm_" + side)
	ik.lower_arm_bone = StringName("lowerarm_" + side)
	ik.hand_bone = StringName("hand_" + side)
	ik.elbow_direction = elbow
	skeleton.add_child(ik)
	ik.target_path = ik.get_path_to(target)
	ik.active = false
	return ik
