class_name SkyCycle
extends Node
## Do fim de tarde à noite durante a partida: o céu (sky_cycle.gdshader) passa pela tarde dourada,
## pelo pôr do sol, pelo crepúsculo e pela noite estrelada com a lua e uma nebulosa; a luz do sol esfria, some e
## vira o luar; a névoa muda de cor; os postes acendem (globo brilhando + luz no chão) e as salas
## acesas atrás das janelas dos prédios começam a brilhar (`WINDOWS`). As nuvens
## giram devagar em volta da cidade e, à noite, as estrelas e a nebulosa giram com o céu.
##
## Segue o relógio da partida (Deathmatch): começo = tarde, fim = noite; "Play Again" volta à
## tarde. Só visual: nada do jogo depende dele. Criado pelo ArenaSetup.
##
## Celular: a luz do ambiente é uma cor (não lê o céu), o reflexo do céu é pequeno (32 px) e
## atualizado aos poucos, e as luzes dos postes longe da câmera se apagam sozinhas.

const SHADER: Shader = preload("res://levels/sky/sky_cycle.gdshader")
## Material das salas atrás das janelas (um só para a cidade toda, ver CityKit): o parâmetro
## `night` faz as salas acesas brilharem, junto com os postes.
const WINDOWS: ShaderMaterial = preload("res://assets/materials/city/MI_FakeInterior.tres")
## Grupo dos globos dos postes (o tools/build_skyplaza.gd põe cada globo nele).
const LAMP_GROUP: StringName = &"lamp_globes"
## Nuvens em volta da cidade (nó no grupo, girado em volta do centro da arena, o dia todo).
const CLOUD_GROUP: StringName = &"drifting_clouds"
## Radianos por segundo: a 120 m do centro uma nuvem anda uns 0,7 m/s (um giro em ~17 min).
const CLOUD_SPIN: float = 0.006
## De onde vem o sol (poente, a oeste, atrás do quarteirão residencial) e onde nasce a lua (leste).
const SUN_AZIMUTH := Vector3(-0.92, 0.0, 0.38)
const MOON_AZIMUTH := Vector3(0.78, 0.0, -0.62)
## A luz não desce abaixo disto (sol rasante demais estica as sombras e causa falhas nelas).
const MIN_LIGHT_ELEVATION: float = 9.0
## Luz de cada poste à noite: alcance (m), força, cor, e a distância da câmera em que ela se apaga.
const LAMP_RANGE: float = 12.0
const LAMP_ENERGY: float = 3.0
const LAMP_COLOR := Color(1.0, 0.78, 0.45)
const LAMP_FADE_BEGIN: float = 26.0
const LAMP_FADE_LENGTH: float = 8.0
## Brilho (bloom) em volta do que é muito claro (globos, lua) à noite; de dia fica desligado.
const NIGHT_GLOW: float = 0.8
## Brilho do globo dos postes de dia e à noite.
const GLOBE_DAY_EMISSION: float = 0.4
const GLOBE_NIGHT_EMISSION: float = 5.0

## Quadros-chave: `at` = quanto da partida passou (0 a 1). Elevações em graus.
const KEYS: Array[Dictionary] = [
	{"at": 0.0, "top": Color(0.24, 0.44, 0.78), "horizon": Color(0.96, 0.8, 0.62),
		"ground_horizon": Color(0.93, 0.8, 0.66), "ground_bottom": Color(0.72, 0.72, 0.8),
		"glow": Color(1.0, 0.62, 0.3), "glow_amount": 0.35, "sun_elevation": 24.0,
		"sun_color": Color(1.0, 0.86, 0.66), "sun_energy": 1.05, "moon_elevation": -10.0,
		"moon_energy": 0.0, "ambient": Color(0.78, 0.74, 0.72), "ambient_energy": 1.0,
		"fog": Color(0.93, 0.82, 0.7), "stars": 0.0, "moon": 0.0, "lamps": 0.0},
	{"at": 0.3, "top": Color(0.2, 0.26, 0.55), "horizon": Color(1.0, 0.52, 0.28),
		"ground_horizon": Color(0.96, 0.5, 0.34), "ground_bottom": Color(0.46, 0.36, 0.5),
		"glow": Color(1.0, 0.42, 0.18), "glow_amount": 1.0, "sun_elevation": 3.0,
		"sun_color": Color(1.0, 0.56, 0.3), "sun_energy": 0.85, "moon_elevation": 0.0,
		"moon_energy": 0.0, "ambient": Color(0.66, 0.52, 0.52), "ambient_energy": 1.0,
		"fog": Color(0.92, 0.56, 0.42), "stars": 0.0, "moon": 0.25, "lamps": 0.35},
	{"at": 0.44, "top": Color(0.12, 0.14, 0.36), "horizon": Color(0.82, 0.42, 0.42),
		"ground_horizon": Color(0.7, 0.4, 0.45), "ground_bottom": Color(0.24, 0.2, 0.34),
		"glow": Color(0.9, 0.34, 0.32), "glow_amount": 0.6, "sun_elevation": -5.0,
		"sun_color": Color(0.95, 0.4, 0.3), "sun_energy": 0.0, "moon_elevation": 8.0,
		"moon_energy": 0.0, "ambient": Color(0.5, 0.45, 0.56), "ambient_energy": 1.0,
		"fog": Color(0.55, 0.38, 0.5), "stars": 0.25, "moon": 0.7, "lamps": 0.85},
	{"at": 0.6, "top": Color(0.05, 0.08, 0.22), "horizon": Color(0.26, 0.28, 0.52),
		"ground_horizon": Color(0.2, 0.22, 0.42), "ground_bottom": Color(0.08, 0.09, 0.2),
		"glow": Color(0.4, 0.3, 0.55), "glow_amount": 0.15, "sun_elevation": -12.0,
		"sun_color": Color(0.9, 0.4, 0.3), "sun_energy": 0.0, "moon_elevation": 20.0,
		"moon_energy": 0.32, "ambient": Color(0.38, 0.41, 0.58), "ambient_energy": 1.0,
		"fog": Color(0.2, 0.23, 0.4), "stars": 0.65, "moon": 1.0, "lamps": 1.0},
	{"at": 0.8, "top": Color(0.015, 0.025, 0.09), "horizon": Color(0.07, 0.11, 0.24),
		"ground_horizon": Color(0.06, 0.09, 0.19), "ground_bottom": Color(0.03, 0.04, 0.09),
		"glow": Color(0.2, 0.2, 0.4), "glow_amount": 0.0, "sun_elevation": -20.0,
		"sun_color": Color(0.9, 0.4, 0.3), "sun_energy": 0.0, "moon_elevation": 32.0,
		"moon_energy": 0.42, "ambient": Color(0.32, 0.36, 0.52), "ambient_energy": 1.0,
		"fog": Color(0.08, 0.1, 0.2), "stars": 1.0, "moon": 1.0, "lamps": 1.0},
	{"at": 1.0, "top": Color(0.012, 0.02, 0.08), "horizon": Color(0.06, 0.1, 0.22),
		"ground_horizon": Color(0.05, 0.08, 0.17), "ground_bottom": Color(0.03, 0.04, 0.08),
		"glow": Color(0.2, 0.2, 0.4), "glow_amount": 0.0, "sun_elevation": -25.0,
		"sun_color": Color(0.9, 0.4, 0.3), "sun_energy": 0.0, "moon_elevation": 40.0,
		"moon_energy": 0.45, "ambient": Color(0.3, 0.34, 0.5), "ambient_energy": 1.0,
		"fog": Color(0.07, 0.09, 0.18), "stars": 1.0, "moon": 1.0, "lamps": 1.0},
]
const MOON_LIGHT_COLOR := Color(0.62, 0.72, 1.0)

## Força um momento do ciclo (0 a 1) em vez do relógio da partida; negativo = segue a partida.
## Usado pelas ferramentas de foto e pelos testes.
var forced_progress: float = -1.0

var environment: Environment
var light: DirectionalLight3D
var material: ShaderMaterial
var lamp_lights: Array[OmniLight3D] = []
var _globe_material: StandardMaterial3D
## O último estado aplicado (para testes e ferramentas).
var state: Dictionary = {}


func _ready() -> void:
	name = "SkyCycle"
	_setup.call_deferred()


func _setup() -> void:
	var world := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if world.is_empty():
		return
	environment = (world[0] as WorldEnvironment).environment
	var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	light = lights[0] as DirectionalLight3D if not lights.is_empty() else null
	material = ShaderMaterial.new()
	material.shader = SHADER
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.glow_hdr_threshold = 1.0
	environment.glow_bloom = 0.05
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_setup_lamps()
	_apply(get_progress())


func _process(delta: float) -> void:
	if material != null:
		_apply(get_progress())
	for node: Node in get_tree().get_nodes_in_group(CLOUD_GROUP):
		(node as Node3D).rotate_y(CLOUD_SPIN * delta)


## Quanto da partida já passou (0 = começo, 1 = fim), ou o momento forçado.
func get_progress() -> float:
	if forced_progress >= 0.0:
		return clampf(forced_progress, 0.0, 1.0)
	var match_mode: Deathmatch = Deathmatch.find(self)
	if match_mode == null or match_mode.duration <= 0.0:
		return 0.0
	return clampf(1.0 - match_mode.time_left / match_mode.duration, 0.0, 1.0)


## A aparência num momento do ciclo (quadros-chave interpolados).
static func sample(progress: float) -> Dictionary:
	var before: Dictionary = KEYS[0]
	var after: Dictionary = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		if progress >= KEYS[i]["at"] and progress <= KEYS[i + 1]["at"]:
			before = KEYS[i]
			after = KEYS[i + 1]
			break
	var span: float = maxf(after["at"] - before["at"], 0.0001)
	var weight: float = smoothstep(0.0, 1.0, clampf((progress - before["at"]) / span, 0.0, 1.0))
	var result: Dictionary = {"progress": progress}
	for key: String in before:
		if key == "at":
			continue
		result[key] = lerp(before[key], after[key], weight)
	return result


# Globo mais claro e uma luz em cada poste (acesas conforme `lamps`).
func _setup_lamps() -> void:
	for node: Node in get_tree().get_nodes_in_group(LAMP_GROUP):
		var globe := node as MeshInstance3D
		if globe == null:
			continue
		if _globe_material == null and globe.material_override is StandardMaterial3D:
			# Um material só para todos os globos (cópia: o recurso da cena fica intacto).
			_globe_material = (globe.material_override as StandardMaterial3D).duplicate()
		globe.material_override = _globe_material
		var lamp := OmniLight3D.new()
		lamp.name = "LampLight"
		lamp.light_color = LAMP_COLOR
		lamp.omni_range = LAMP_RANGE
		lamp.omni_attenuation = 1.0
		lamp.shadow_enabled = false
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = LAMP_FADE_BEGIN
		lamp.distance_fade_length = LAMP_FADE_LENGTH
		lamp.visible = false
		globe.add_child(lamp)
		# Logo abaixo do globo (não fica dentro dele).
		lamp.position = Vector3(0.0, -0.35, 0.0)
		lamp_lights.append(lamp)


func _apply(progress: float) -> void:
	state = sample(progress)
	var sun_dir: Vector3 = _direction(SUN_AZIMUTH, state["sun_elevation"])
	var moon_dir: Vector3 = _direction(MOON_AZIMUTH, state["moon_elevation"])
	material.set_shader_parameter(&"sky_top", state["top"])
	material.set_shader_parameter(&"sky_horizon", state["horizon"])
	material.set_shader_parameter(&"ground_horizon", state["ground_horizon"])
	material.set_shader_parameter(&"ground_bottom", state["ground_bottom"])
	material.set_shader_parameter(&"glow_color", state["glow"])
	material.set_shader_parameter(&"glow_amount", state["glow_amount"])
	material.set_shader_parameter(&"sun_direction", sun_dir)
	material.set_shader_parameter(&"sun_color", state["sun_color"])
	material.set_shader_parameter(&"stars_amount", state["stars"])
	# A nebulosa só aparece com o céu bem escuro (depois das estrelas).
	material.set_shader_parameter(&"nebula_amount", smoothstep(0.35, 1.0, state["stars"]))
	material.set_shader_parameter(&"moon_direction", moon_dir)
	material.set_shader_parameter(&"moon_amount", state["moon"])

	environment.ambient_light_color = state["ambient"]
	environment.ambient_light_energy = state["ambient_energy"]
	environment.fog_light_color = state["fog"]

	# Uma luz só: é o sol enquanto ele ilumina mais que a lua, depois vira o luar (a troca
	# acontece com as duas quase apagadas, então não se vê o pulo).
	if light != null:
		var sun_on: bool = state["sun_energy"] >= state["moon_energy"]
		var elevation: float = state["sun_elevation"] if sun_on else state["moon_elevation"]
		var from: Vector3 = _direction(SUN_AZIMUTH if sun_on else MOON_AZIMUTH,
				maxf(elevation, MIN_LIGHT_ELEVATION))
		light.look_at_from_position(light.global_position, light.global_position - from,
				Vector3.UP if absf(from.y) < 0.99 else Vector3.FORWARD)
		light.light_color = state["sun_color"] if sun_on else MOON_LIGHT_COLOR
		light.light_energy = state["sun_energy"] if sun_on else state["moon_energy"]
		light.visible = light.light_energy > 0.01
	state["light_on_sun"] = light == null or state["sun_energy"] >= state["moon_energy"]

	var lamps: float = state["lamps"]
	environment.glow_enabled = lamps > 0.05
	environment.glow_intensity = NIGHT_GLOW * lamps
	if _globe_material != null:
		_globe_material.emission_energy_multiplier = lerpf(GLOBE_DAY_EMISSION, GLOBE_NIGHT_EMISSION, lamps)
	for lamp: OmniLight3D in lamp_lights:
		lamp.light_energy = LAMP_ENERGY * lamps
		lamp.visible = lamps > 0.02
	WINDOWS.set_shader_parameter(&"night", lamps)


# Direção PARA o astro: `azimuth` no plano do chão, subindo `elevation` graus.
static func _direction(azimuth: Vector3, elevation: float) -> Vector3:
	var e: float = deg_to_rad(elevation)
	return (azimuth.normalized() * cos(e) + Vector3.UP * sin(e)).normalized()
