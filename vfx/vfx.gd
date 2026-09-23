class_name Vfx
## Efeitos visuais passageiros: fumaça do cano, poeira e marca do tiro, faíscas do gancho no
## trilho, poeira da aterrissagem, a fumaça em que o corpo some e o brilho de quem renasce.
## Imagens do Kenney Particle Pack (CC0), tingidas aqui.
##
## Só enfeitam: nada do jogo depende deles. Cada efeito é um nó que se apaga sozinho; as malhas e
## os materiais são criados uma vez e compartilhados (no celular, menos trocas de estado na GPU).

const SMOKE: Texture2D = preload("res://assets/vfx/kenney/smoke_04.png")
const CLOUD: Texture2D = preload("res://assets/vfx/kenney/smoke_07.png")
const DIRT: Texture2D = preload("res://assets/vfx/kenney/dirt_01.png")
const MARK: Texture2D = preload("res://assets/vfx/kenney/circle_05.png")
const RING: Texture2D = preload("res://assets/vfx/kenney/circle_02.png")
const GLOW: Texture2D = preload("res://assets/vfx/kenney/star_05.png")
const FLASH: Texture2D = preload("res://assets/vfx/kenney/star_09.png")

## Tamanho da marca do tiro na parede (m) e quanto tempo ela fica antes de sumir (s).
const MARK_SIZE: float = 0.13
const MARK_LIFETIME: float = 12.0
const MUZZLE_COLOR := Color(1.0, 0.86, 0.55)
const SPAWN_COLOR := Color(1.0, 0.82, 0.42)

static var _particle_meshes: Dictionary[String, QuadMesh] = {}
static var _quad_meshes: Dictionary[String, QuadMesh] = {}
static var _fade: Gradient
static var _grow: Curve
static var _shrink: Curve


## Fumaça que sai do cano depois do tiro (`forward` = para onde a arma aponta). `size` menor na
## 1ª pessoa: o cano fica a meio metro da câmera e a fumaça cobriria a mira.
static func muzzle_smoke(parent: Node, at: Vector3, forward: Vector3, size: float = 1.0) -> CPUParticles3D:
	var smoke := _burst(SMOKE, false, 3, 0.8, Color(0.85, 0.83, 0.8, 0.35 * minf(size * 1.5, 1.0)))
	smoke.name = "MuzzleSmoke"
	smoke.spread = 20.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.2
	smoke.damping_min = 1.5
	smoke.damping_max = 2.5
	smoke.gravity = Vector3(0.0, 0.35, 0.0)
	smoke.scale_amount_min = 0.3 * size
	smoke.scale_amount_max = 0.4 * size
	return _fire(parent, smoke, at, forward)


## Clarão do cano visto de fora (a 1ª pessoa tem o dela, no ViewModel).
static func muzzle_flash(parent: Node, at: Vector3, size: float) -> MeshInstance3D:
	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	flash.mesh = _quad(FLASH, true, true, MUZZLE_COLOR)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash, true)
	flash.global_position = at
	flash.scale = Vector3.ONE * size
	var tween := flash.create_tween()
	tween.tween_property(flash, ^"transparency", 1.0, 0.07)
	tween.tween_callback(flash.queue_free)
	return flash


## Poeira do tiro que acerta o cenário (`with_debris`: lascas voando, só no raio principal).
static func impact_dust(parent: Node, at: Vector3, normal: Vector3, with_debris: bool) -> CPUParticles3D:
	var dust := _burst(SMOKE, false, 4, 0.55, Color(0.8, 0.76, 0.68, 0.6))
	dust.name = "ImpactDust"
	dust.spread = 35.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.8
	dust.damping_min = 3.0
	dust.damping_max = 4.0
	dust.gravity = Vector3(0.0, -1.5, 0.0)
	dust.scale_amount_min = 0.3
	dust.scale_amount_max = 0.45
	_fire(parent, dust, at + normal * 0.05, normal)
	if with_debris:
		var debris := _burst(DIRT, false, 2, 0.4, Color(0.55, 0.5, 0.44, 0.9))
		debris.name = "ImpactDebris"
		debris.spread = 45.0
		debris.initial_velocity_min = 2.0
		debris.initial_velocity_max = 3.5
		debris.gravity = Vector3(0.0, -9.8, 0.0)
		debris.scale_amount_min = 0.18
		debris.scale_amount_max = 0.26
		_fire(parent, debris, at + normal * 0.05, normal)
	return dust


## Faíscas do tiro que acerta o cenário: pontos de brilho que saltam da superfície e caem.
static func impact_sparks(parent: Node, at: Vector3, normal: Vector3) -> CPUParticles3D:
	var sparks := _burst(GLOW, true, 10, 0.35, Color(1.0, 0.75, 0.35))
	sparks.name = "ImpactSparks"
	sparks.scale_amount_curve = _shrink_curve()
	sparks.spread = 40.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0.0, -9.8, 0.0)
	sparks.scale_amount_min = 0.05
	sparks.scale_amount_max = 0.1
	return _fire(parent, sparks, at + normal * 0.02, normal)


## Nuvem pequena do tiro que acerta alguém (sem sangue: o corpo também pisca, no CharacterModel).
static func body_puff(parent: Node, at: Vector3, normal: Vector3) -> CPUParticles3D:
	var puff := _burst(SMOKE, false, 3, 0.4, Color(0.95, 0.92, 0.88, 0.5))
	puff.name = "BodyPuff"
	puff.spread = 40.0
	puff.initial_velocity_min = 0.5
	puff.initial_velocity_max = 1.2
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	puff.scale_amount_min = 0.2
	puff.scale_amount_max = 0.3
	return _fire(parent, puff, at + normal * 0.05, normal)


## Marca escura que o tiro deixa na parede ou no chão; some sozinha depois de `MARK_LIFETIME`.
static func bullet_mark(parent: Node, at: Vector3, normal: Vector3) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "BulletMark"
	mark.mesh = _quad(MARK, false, false, Color(0.07, 0.06, 0.05, 0.85))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark, true)
	# O quadrado olha para fora da superfície (+Z = normal), um pouco afastado dela e girado ao acaso.
	var n: Vector3 = normal.normalized()
	var up_hint: Vector3 = Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	var basis := Basis.looking_at(-n, up_hint).rotated(n, randf() * TAU)
	mark.global_transform = Transform3D(basis.scaled(Vector3.ONE * MARK_SIZE * randf_range(0.8, 1.2)), at + n * 0.01)
	var tween := mark.create_tween()
	tween.tween_interval(MARK_LIFETIME)
	tween.tween_property(mark, ^"transparency", 1.0, 1.5)
	tween.tween_callback(mark.queue_free)
	return mark


## Poeira que abre em roda quando o personagem cai de uma altura (`strength` de 0 a 1).
static func landing_dust(parent: Node, at: Vector3, strength: float) -> CPUParticles3D:
	var dust := _burst(SMOKE, false, roundi(lerpf(5.0, 10.0, strength)), 0.7, Color(0.86, 0.83, 0.76, 0.55))
	dust.name = "LandingDust"
	# Em todas as direções, rente ao chão.
	dust.direction = Vector3.RIGHT
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.5 * (0.6 + strength)
	dust.damping_min = 3.0
	dust.damping_max = 4.0
	dust.gravity = Vector3(0.0, 0.3, 0.0)
	dust.scale_amount_min = 0.35
	dust.scale_amount_max = 0.55
	return _fire(parent, dust, at + Vector3.UP * 0.1, Vector3.UP)


## Fumaça em que o corpo de quem morreu some (na hora em que ele renasce em outro lugar).
static func death_poof(parent: Node, at: Vector3) -> CPUParticles3D:
	var poof := _burst(CLOUD, false, 14, 1.1, Color(0.93, 0.93, 0.95, 0.85))
	poof.name = "DeathPoof"
	# Nuvens espalhadas pelo corpo deitado, abrindo para todo lado.
	poof.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	poof.emission_box_extents = Vector3(0.6, 0.25, 0.6)
	poof.spread = 180.0
	poof.initial_velocity_min = 0.4
	poof.initial_velocity_max = 1.4
	poof.damping_min = 1.0
	poof.damping_max = 1.5
	poof.gravity = Vector3(0.0, 0.6, 0.0)
	poof.scale_amount_min = 0.6
	poof.scale_amount_max = 1.0
	# Centro acima do chão: nuvem grande atravessando o piso fica com um corte reto.
	return _fire(parent, poof, at + Vector3.UP * 0.7, Vector3.UP)


## Anel dourado no chão e brilhos subindo onde alguém acabou de nascer.
static func spawn_ring(parent: Node, at: Vector3) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "SpawnRing"
	ring.mesh = _quad(RING, true, false, SPAWN_COLOR)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring, true)
	# Deitado no chão (o quadrado olha para cima).
	ring.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.5), at + Vector3.UP * 0.05)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3.ONE * 2.6, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, ^"transparency", 1.0, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

	var sparkles := _burst(GLOW, true, 10, 0.9, SPAWN_COLOR)
	sparkles.name = "SpawnSparkles"
	sparkles.scale_amount_curve = _shrink_curve()
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparkles.emission_ring_axis = Vector3.UP
	sparkles.emission_ring_radius = 0.5
	sparkles.emission_ring_inner_radius = 0.35
	sparkles.emission_ring_height = 0.1
	sparkles.explosiveness = 0.6
	sparkles.spread = 10.0
	sparkles.initial_velocity_min = 1.2
	sparkles.initial_velocity_max = 2.4
	sparkles.damping_min = 1.0
	sparkles.damping_max = 1.5
	sparkles.scale_amount_min = 0.12
	sparkles.scale_amount_max = 0.2
	_fire(parent, sparkles, at + Vector3.UP * 0.1, Vector3.UP)
	return ring


## Faíscas contínuas do gancho raspando no trilho: quem usa liga `emitting` e move o nó.
static func rail_sparks() -> CPUParticles3D:
	# Sem somar luz: contra o céu claro o brilho somado vira uma bola branca.
	var sparks := _burst(GLOW, false, 30, 0.3, Color(1.0, 0.62, 0.18))
	sparks.name = "RailSparks"
	sparks.scale_amount_curve = _shrink_curve()
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.direction = Vector3.DOWN
	sparks.spread = 45.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3(0.0, -14.0, 0.0)
	sparks.scale_amount_min = 0.04
	sparks.scale_amount_max = 0.07
	sparks.emitting = false
	return sparks


# Partículas de uma vez só, que vão sumindo (alfa) e crescendo; `additive` = brilho (soma luz).
static func _burst(texture: Texture2D, additive: bool, amount: int, lifetime: float, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	# Nasce DESLIGADO: ligado (o padrão), ele solta tudo ao entrar na cena, ainda na origem do
	# mapa, antes de ir para o lugar certo (as faíscas saíam dentro do monumento da praça).
	particles.emitting = false
	particles.mesh = _particle_mesh(texture, additive)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.gravity = Vector3.ZERO
	particles.color = color
	particles.color_ramp = _fade_ramp()
	particles.scale_amount_curve = _grow_curve()
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


# Põe no mundo com o "para cima" das partículas apontando para `up` e solta.
static func _fire(parent: Node, particles: CPUParticles3D, at: Vector3, up: Vector3) -> CPUParticles3D:
	# Nome legível mesmo repetido ("ImpactDust2"): os testes acham os efeitos pelo nome.
	parent.add_child(particles, true)
	var axis: Vector3 = up.normalized() if up.length() > 0.001 else Vector3.UP
	particles.global_transform = Transform3D(Basis(_rotation_to(axis)), at)
	particles.finished.connect(particles.queue_free)
	particles.restart()
	return particles


static func _rotation_to(axis: Vector3) -> Quaternion:
	if axis.dot(Vector3.UP) < -0.999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(Vector3.UP, axis)


static func _particle_mesh(texture: Texture2D, additive: bool) -> QuadMesh:
	var key: String = "%s:%s" % [texture.resource_path, additive]
	if not _particle_meshes.has(key):
		var material := _material(texture, additive)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		var mesh := QuadMesh.new()
		mesh.material = material
		_particle_meshes[key] = mesh
	return _particle_meshes[key]


# Quadrado solto (marca, anel, clarão): a cor vai no material, o sumiço no `transparency` do nó.
static func _quad(texture: Texture2D, additive: bool, billboard: bool, color: Color) -> QuadMesh:
	var key: String = "%s:%s:%s:%s" % [texture.resource_path, additive, billboard, color.to_html()]
	if not _quad_meshes.has(key):
		var material := _material(texture, additive)
		material.albedo_color = color
		if billboard:
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.billboard_keep_scale = true
		var mesh := QuadMesh.new()
		mesh.material = material
		_quad_meshes[key] = mesh
	return _quad_meshes[key]


static func _material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	return material


static func _fade_ramp() -> Gradient:
	if _fade == null:
		_fade = Gradient.new()
		_fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		_fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_fade.add_point(0.55, Color(1.0, 1.0, 1.0, 0.75))
	return _fade


static func _grow_curve() -> Curve:
	if _grow == null:
		_grow = Curve.new()
		_grow.add_point(Vector2(0.0, 0.4))
		_grow.add_point(Vector2(1.0, 1.0))
	return _grow


# Faíscas e brilhos diminuem até sumir (fumaça e poeira crescem, `_grow_curve`).
static func _shrink_curve() -> Curve:
	if _shrink == null:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0.0, 1.0))
		_shrink.add_point(Vector2(1.0, 0.25))
	return _shrink
