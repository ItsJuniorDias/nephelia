class_name WeaponCatalog
extends RefCounted
## Fichas das armas do jogo, montadas em código (uma só cópia de cada, compartilhada).
##
## O revólver é a arma de sempre: munição infinita e um item nunca o tira. As outras duas
## aparecem como itens na arena, com munição contada; quando acaba, o personagem volta ao
## revólver. As malhas saem de `tools/bake_weapons.gd` (o FBX original não serve: ver CLAUDE.md).
##
## Espaço de uma arma (igual nas três): +Y para cima, cano para -Z, +X é o lado direito de quem
## segura. As pegadas das armas longas são descritas como a mão de verdade: onde ela aperta
## (ponto de contato), para onde vão os nós dos dedos e para onde aponta o polegar. Conferir
## com `tools/pose_sheet.gd` (fotos de fora e em 1ª pessoa).

const DEFAULT_ID: StringName = &"revolver"

## Giro da arma na palma da mão direita, igual para as três (são modeladas do mesmo jeito).
const HAND_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
## Do pulso até o meio do que a mão fechada aperta (medido no revólver da animação: 0,10 m).
const GRIP_REACH: float = 0.09
## O que a mão aperta fica um pouco para o lado da palma.
const PALM_DEPTH: float = 0.02

static var _weapons: Dictionary[StringName, WeaponData] = {}


## Ficha de uma arma pelo nome ("revolver", "repeater", "shotgun"), ou null.
static func get_weapon(id: StringName) -> WeaponData:
	if _weapons.is_empty():
		_build()
	return _weapons.get(id)


## A arma que todo mundo carrega e nunca acaba.
static func default_weapon() -> WeaponData:
	return get_weapon(DEFAULT_ID)


## Pose do PULSO para uma mão que aperta `contact` (espaço da arma), com os nós dos dedos
## apontando para `fingers` e o polegar para perto de `thumb`. Serve para as duas mãos: o
## esqueleto é espelhado, então com as mesmas direções a palma da esquerda fica do outro lado.
static func hand_pose(contact: Vector3, fingers: Vector3, thumb: Vector3, left: bool) -> Transform3D:
	var y: Vector3 = fingers.normalized()
	var z: Vector3 = (thumb - y * thumb.dot(y)).normalized()
	var x: Vector3 = y.cross(z)
	# Palma: -X na mão direita, +X na esquerda (medido na pose de descanso do modelo).
	var palm: Vector3 = x if left else -x
	return Transform3D(Basis(x, y, z), contact - y * GRIP_REACH - palm * PALM_DEPTH)


static func _build() -> void:
	# Revólver: o básico. Três tiros certeiros derrubam alguém.
	_weapons[DEFAULT_ID] = _make({
		"id": DEFAULT_ID, "weapon_name": "Revolver", "damage": 34.0, "fire_interval": 0.35,
		"magazine_size": 6, "reload_time": 1.6, "max_range": 80.0, "spread_degrees": 0.6,
		"reserve_ammo": -1, "mesh": "colt_revolver",
		"hand_offset": Vector3(0.0, 0.18, -0.05), "barrel_tip": Vector3(0.0005, 0.1477, -0.19),
	})
	# Repetidora: bate forte e longe, mas é lenta. Dois tiros derrubam.
	# Mão direita no punho da coronha (z 0,10 a 0,22), esquerda por baixo da telha (z -0,34 a -0,06).
	_weapons[&"repeater"] = _make({
		"id": &"repeater", "weapon_name": "Repeater", "damage": 55.0, "fire_interval": 0.55,
		"magazine_size": 8, "reload_time": 2.2, "max_range": 120.0, "spread_degrees": 0.25,
		"reserve_ammo": 16, "mesh": "repeater",
		"hand_offset": Vector3(0.0, 0.4, -0.07), "barrel_tip": Vector3(0.0133, 0.1892, -0.6566),
		"right_hand": [Vector3(0.014, 0.10, 0.17), Vector3(-0.5, -0.1, -0.85), Vector3(0, 1, 0)],
		"left_hand": [Vector3(0.014, 0.155, -0.07), Vector3(0.7, 0.5, -0.5), Vector3(0, 0.2, -1)],
		"mount_at": Vector3(-0.04, 1.24, 0.09), "aim": Vector3(-1.0, 192.0, 0.0),
		# Recarga: gira de lado para mostrar a janela de carga e a alavanca.
		"recoil": 1.4, "shot_pitch": 0.82, "shot_volume_db": 2.0, "flash_scale": 1.3,
		"reload_motion": Vector3(-14.0, 38.0, 0.04),
	})
	# Espingarda: dois canos de chumbo grosso. De perto derruba de um tiro; de longe não faz nada.
	# Mão direita no punho (z 0,04 a 0,24, descendo), esquerda na telha (z -0,16 a -0,04).
	_weapons[&"shotgun"] = _make({
		"id": &"shotgun", "weapon_name": "Shotgun", "damage": 12.0, "fire_interval": 0.75,
		"magazine_size": 2, "reload_time": 1.9, "max_range": 28.0, "spread_degrees": 6.5,
		"pellets": 8, "reserve_ammo": 8, "mesh": "double_barrel_shotgun",
		"hand_offset": Vector3(0.0, 0.38, 0.05), "barrel_tip": Vector3(-0.0002, 0.0298, -0.5613),
		"right_hand": [Vector3(0.0, -0.035, 0.15), Vector3(-0.5, -0.1, -0.85), Vector3(0, 1, 0)],
		"left_hand": [Vector3(0.0, -0.01, -0.07), Vector3(0.7, 0.5, -0.5), Vector3(0, 0.2, -1)],
		"mount_at": Vector3(-0.04, 1.26, 0.09), "aim": Vector3(-1.0, 192.0, 0.0),
		# Recarga: "quebra" a arma, com o cano para baixo, para trocar os cartuchos.
		"recoil": 1.8, "shot_pitch": 0.68, "shot_volume_db": 4.0, "flash_scale": 1.9,
		"reload_motion": Vector3(-36.0, 8.0, 0.06),
	})


static func _make(spec: Dictionary) -> WeaponData:
	var data := WeaponData.new()
	for key: String in ["id", "weapon_name", "damage", "fire_interval", "magazine_size",
			"reload_time", "max_range", "spread_degrees", "pellets", "reserve_ammo", "barrel_tip",
			"recoil", "shot_pitch", "shot_volume_db", "flash_scale", "reload_motion"]:
		if spec.has(key):
			data.set(key, spec[key])
	data.resource_name = data.weapon_name
	data.mesh = load("res://assets/models/weapons/%s.res" % spec["mesh"])
	data.in_hand = Transform3D(HAND_BASIS, spec["hand_offset"])
	# Arma longa: apoiada na frente do peito (espaço do esqueleto, o personagem olha para +Z),
	# apontada para onde "aim" manda, com o ponto da mão direita em "mount_at". As duas mãos
	# vão até ela pela IK.
	if spec.has("right_hand"):
		var right: Array = spec["right_hand"]
		var left: Array = spec["left_hand"]
		data.right_grip = hand_pose(right[0], right[1], right[2], false)
		data.fore_grip = hand_pose(left[0], left[1], left[2], true)
		var aim: Basis = Basis.from_euler(spec["aim"] * (PI / 180.0))
		data.chest_mount = Transform3D(aim, spec["mount_at"] - aim * right[0])
	return data
