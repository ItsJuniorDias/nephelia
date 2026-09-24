class_name TorsoFacingModifier
extends SkeletonModifier3D
## Mantém o tronco na pose de mira enquanto as pernas correm para qualquer lado: as corridas da
## Universal Animation Library Pro giram o quadril (28° a 45° de lado e na diagonal, medido) e o
## inclinam (20° para a frente correndo para a frente, 9° para trás de costas), e o tronco (pose de
## mira, do `spine_01` para cima) iria junto, apontando a arma para o lado ou para cima.
##
## A pose de mira do revólver foi calibrada com as pernas PARADAS (animação "Idle"): o modificador
## gira o `spine_01` de volta como se o quadril estivesse na posição média do parado
## (`reference`), a cada quadro. O tronco fica firme na pose de mira (sobe e desce com o corpo,
## mas não torce com a passada), como nos jogos de tiro: uma média do quadril que deixasse passar
## o balanço da passada deixou o tronco até 42° fora da mira (o quadril gira muito a cada passo).
##
## Primeiro modificador do esqueleto (antes da arma no peito e das mãos). O efeito de um
## SkeletonModifier3D é temporário (não dá para ler a pose depois): `hips_yaw` guarda o giro do
## quadril e `torso_rotation` como o tronco ficou depois da correção (para os testes).

@export var hips_bone: StringName = &"pelvis"
@export var torso_bone: StringName = &"spine_01"

## Rotação do quadril (espaço do esqueleto) para a qual a pose de mira foi feita.
var reference: Quaternion = Quaternion.IDENTITY
var hips_yaw: float = 0.0
var torso_rotation: Quaternion = Quaternion.IDENTITY


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	var hips: int = skeleton.find_bone(hips_bone)
	var torso: int = skeleton.find_bone(torso_bone)
	if hips < 0 or torso < 0:
		return
	var hips_rotation: Quaternion = skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()
	hips_yaw = yaw_of(Basis(hips_rotation))
	var correction := Basis(reference * hips_rotation.inverse())
	var pose: Transform3D = skeleton.get_bone_global_pose(torso)
	var parent: int = skeleton.get_bone_parent(torso)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var turned: Basis = correction * pose.basis
	skeleton.set_bone_pose_rotation(torso, (parent_basis.inverse() * turned).get_rotation_quaternion())
	torso_rotation = skeleton.get_bone_global_pose(torso).basis.get_rotation_quaternion()


## Rotação média do quadril numa animação (espaço do esqueleto), montada osso a osso a partir das
## trilhas (sem tocar a animação).
static func average_hips(skeleton: Skeleton3D, animation: Animation, bone_name: StringName = &"pelvis") -> Quaternion:
	var bone: int = skeleton.find_bone(bone_name)
	var average := Quaternion.IDENTITY
	var samples: int = 8
	for i in samples:
		var time: float = animation.length * i / samples
		var rotation := Quaternion.IDENTITY
		var current: int = bone
		while current >= 0:
			rotation = _local_rotation(skeleton, animation, current, time) * rotation
			current = skeleton.get_bone_parent(current)
		average = rotation if i == 0 else average.slerp(rotation, 1.0 / (i + 1))
	return average


## Para onde o osso aponta em volta do eixo vertical (0 = a frente do modelo).
static func yaw_of(basis: Basis) -> float:
	return atan2(basis.z.x, basis.z.z)


static func _local_rotation(skeleton: Skeleton3D, animation: Animation, bone: int, time: float) -> Quaternion:
	var path := NodePath("Armature/Skeleton3D:%s" % skeleton.get_bone_name(bone))
	var track: int = animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if track >= 0:
		return animation.rotation_track_interpolate(track, time)
	return skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
