class_name WeaponGripModifier
extends SkeletonModifier3D
## Leva uma mão até um ponto da arma, por cima da animação (IK de dois ossos).
##
## Todas as animações do personagem são de pistola: com um rifle elas não servem. Para as armas
## longas a arma é apoiada no peito e as DUAS mãos são levadas até ela por dois destes
## modificadores (um por braço), dobrando ombro e cotovelo pela lei dos cossenos.
## O `TwoBoneIK3D` do Godot 4.7 não mexeu neste esqueleto; esta conta dá para conferir em teste.
## Lembrete: o efeito de um SkeletonModifier3D é temporário — não adianta ler a pose depois
## (por isso `miss` guarda o resultado).

@export var upper_arm_bone: StringName = &"upperarm_l"
@export var lower_arm_bone: StringName = &"lowerarm_l"
@export var hand_bone: StringName = &"hand_l"
## Nó que marca a pose do pulso (fica preso na arma).
@export var target_path: NodePath
## Para onde o cotovelo tende a apontar (espaço do esqueleto): para baixo e para fora.
@export var elbow_direction: Vector3 = Vector3(0.5, -1.0, -0.2)
## Cotovelo no lugar que deixa o pulso reto: o antebraço continua na direção dos dedos, em vez
## de a mão dobrar num ângulo impossível.
@export var align_elbow_to_hand: bool = true
## Fecha os dedos copiando os da outra mão, espelhados (ex.: "hand_r"). Na animação de pistola
## a mão esquerda é de apoio, aberta; segurando uma telha de rifle ela precisa fechar.
@export var copy_fingers_from: StringName = &""

## Quanto o pulso ficou longe do alvo na última vez (0 = chegou; > 0 = o braço não alcança).
var miss: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	var upper: int = skeleton.find_bone(upper_arm_bone)
	var lower: int = skeleton.find_bone(lower_arm_bone)
	var hand: int = skeleton.find_bone(hand_bone)
	if upper < 0 or lower < 0 or hand < 0:
		return
	var target := get_node_or_null(target_path) as Node3D
	if target == null or not target.is_inside_tree():
		return

	# Tamanho de cada osso: na pose de descanso, o filho fica na ponta do pai.
	var upper_axis: Vector3 = skeleton.get_bone_rest(lower).origin
	var lower_axis: Vector3 = skeleton.get_bone_rest(hand).origin
	var upper_length: float = upper_axis.length()
	var lower_length: float = lower_axis.length()
	if upper_length < 0.001 or lower_length < 0.001:
		return

	var upper_pose: Transform3D = skeleton.get_bone_global_pose(upper)
	var lower_pose: Transform3D = skeleton.get_bone_global_pose(lower)
	var goal: Transform3D = skeleton.global_transform.affine_inverse() * target.global_transform
	goal.basis = goal.basis.orthonormalized()
	var shoulder: Vector3 = upper_pose.origin
	var to_goal: Vector3 = goal.origin - shoulder
	if to_goal.length_squared() < 0.000001:
		return
	# Longe demais: o braço estica até onde chega (não desmonta o ombro).
	var reach: float = upper_length + lower_length - 0.01
	var distance: float = clampf(to_goal.length(), absf(upper_length - lower_length) + 0.01, reach)
	miss = maxf(to_goal.length() - reach, 0.0)
	var aim: Vector3 = to_goal.normalized()

	# Cotovelo: lei dos cossenos. `along` é o quanto ele avança na linha do ombro até a mão e
	# `out` o quanto ele sai dela, para o lado de `side`.
	var along: float = (upper_length * upper_length - lower_length * lower_length
			+ distance * distance) / (2.0 * distance)
	var out: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var side: Vector3 = _flat(elbow_direction, aim)
	if align_elbow_to_hand:
		# Onde o cotovelo ficaria com o pulso reto: atrás da mão, na direção contrária aos dedos.
		var straight: Vector3 = _flat(goal.origin - goal.basis.y * lower_length - shoulder, aim)
		if straight.length_squared() > 0.0001:
			side = straight + side * 0.35
	side = _flat(side, aim)
	if side.length_squared() < 0.0001:
		side = _flat(Vector3.DOWN, aim)
	var elbow: Vector3 = shoulder + aim * along + side * out
	var wrist: Vector3 = shoulder + aim * distance

	# Ombro: gira até o braço apontar para o cotovelo (mantendo o "rolamento" da animação).
	var turn_upper: Quaternion = _turn((upper_pose.basis * upper_axis).normalized(),
			(elbow - shoulder).normalized())
	var upper_basis: Basis = Basis(turn_upper) * upper_pose.basis
	_apply(skeleton, upper, upper_basis, skeleton.get_bone_global_pose(skeleton.get_bone_parent(upper)).basis)

	# Cotovelo: o giro do ombro já levou o antebraço junto; daí ele aponta para a mão.
	var lower_carried: Basis = Basis(turn_upper) * lower_pose.basis
	var turn_lower: Quaternion = _turn((lower_carried * lower_axis).normalized(),
			(wrist - elbow).normalized())
	var lower_basis: Basis = Basis(turn_lower) * lower_carried
	_apply(skeleton, lower, lower_basis, upper_basis)

	# Mão: gira como o alvo pede (a pegada da arma).
	_apply(skeleton, hand, goal.basis, lower_basis)
	if not copy_fingers_from.is_empty():
		_copy_fingers(skeleton, skeleton.find_bone(copy_fingers_from), hand)


# Copia a pose dos dedos de uma mão para a outra. O esqueleto é espelhado no eixo X (conferido
# na pose de descanso), e espelhar um giro assim troca o sinal de y e z do quaternion.
func _copy_fingers(skeleton: Skeleton3D, source: int, target: int) -> void:
	if source < 0:
		return
	var suffix_from: String = skeleton.get_bone_name(source).right(2)
	var suffix_to: String = skeleton.get_bone_name(target).right(2)
	for child: int in skeleton.get_bone_children(source):
		var child_name: String = skeleton.get_bone_name(child)
		var mirror: int = skeleton.find_bone(child_name.trim_suffix(suffix_from) + suffix_to)
		if mirror < 0:
			continue
		var turn: Quaternion = skeleton.get_bone_pose_rotation(child)
		skeleton.set_bone_pose_rotation(mirror, Quaternion(turn.x, -turn.y, -turn.z, turn.w))
		_copy_fingers(skeleton, child, mirror)


# `vector` sem a parte na direção de `axis`, normalizado (zero se não sobrar nada).
func _flat(vector: Vector3, axis: Vector3) -> Vector3:
	var flat: Vector3 = vector - axis * vector.dot(axis)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.ZERO


# Giro que leva `from` a `to` (com saída para o caso de serem opostos).
func _turn(from: Vector3, to: Vector3) -> Quaternion:
	if from.dot(to) < -0.9999:
		var any_axis: Vector3 = from.cross(Vector3.UP)
		if any_axis.length_squared() < 0.0001:
			any_axis = from.cross(Vector3.RIGHT)
		return Quaternion(any_axis.normalized(), PI)
	return Quaternion(from, to)


# Escreve no osso a pose que, com o giro do pai, dá a posição global pedida.
func _apply(skeleton: Skeleton3D, bone: int, global_basis: Basis, parent_basis: Basis) -> void:
	var local: Basis = parent_basis.orthonormalized().inverse() * global_basis.orthonormalized()
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
