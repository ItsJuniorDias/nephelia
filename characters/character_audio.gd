class_name CharacterAudio
extends Node3D
## Sons de um personagem, em 3D (dá para ouvir os inimigos): passos conforme o chão, pulo,
## aterrissagem, dano, morte, trilho (engate e chiado deslizando) e a recarga dos OUTROS (a do
## jogador local sai dos braços em 1ª pessoa, sem posição).
##
## Só escuta o Character (sinais e velocidade): não muda nada no jogo. Criado em código pelo
## Character, como a arma (nó guardado em cena instanciada some no build do iPhone).

## Distância andada por passo (a 5 m/s dá uns 3 passos por segundo).
const STEP_DISTANCE: float = 1.7
## Velocidade mínima (no chão) para contar passos.
const STEP_MIN_SPEED: float = 1.0
## Queda mais rápida que isto faz o som de aterrissagem.
const LAND_MIN_SPEED: float = 3.5
## Os passos do próprio jogador são mais baixos (tocam o tempo todo, bem no ouvido).
const OWN_STEP_DB: float = -10.0
const OTHER_STEP_DB: float = -3.0
## Chiado do trilho: volume e tom sobem com a velocidade.
const RAIL_SLIDE_DB: float = -8.0

var character: Character

## Contagem de passos (para os testes e para variar o som).
var steps_played: int = 0
var last_step_kind: StringName = &""

var _step_travel: float = 0.0
var _was_grounded: bool = true
var _fall_speed: float = 0.0
var _slide: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


## Chamado pelo Character quando ele está pronto.
func setup(for_character: Character) -> void:
	character = for_character
	name = "CharacterAudio"
	_rng.seed = hash(character.name)
	character.hit_received.connect(_on_hit_received)
	character.died.connect(func(_killer: Character) -> void: _play(Sounds.DEATH, 0.0, 0.75))
	character.rail_attached.connect(_on_rail_attached)
	character.rail_detached.connect(_stop_slide)
	if character.weapon != null:
		character.weapon.reload_started.connect(_on_reload_started)
	_slide = AudioStreamPlayer3D.new()
	_slide.name = "RailSlide"
	_slide.stream = Sounds.RAIL_SLIDE
	_slide.bus = Sounds.SFX_BUS
	_slide.volume_db = RAIL_SLIDE_DB
	add_child(_slide)


func is_local() -> bool:
	return character != null and character.controller is HumanController


func is_sliding() -> bool:
	return _slide != null and _slide.playing


func _physics_process(delta: float) -> void:
	if character == null or not character.is_alive:
		_was_grounded = true
		return
	var grounded: bool = character.is_grounded()
	if character.is_on_rail:
		_update_slide()
		_was_grounded = false
		return
	if grounded and not _was_grounded:
		# Chegou no chão: baque proporcional à queda (pulinho quase não faz barulho).
		if _fall_speed > LAND_MIN_SPEED:
			var strength: float = clampf((_fall_speed - LAND_MIN_SPEED) / 8.0, 0.0, 1.0)
			_play(Sounds.LAND, lerpf(-12.0, 0.0, strength), _rng.randf_range(0.9, 1.05))
		_step_travel = 0.0
	elif not grounded and _was_grounded and character.velocity.y > 1.0:
		_play(Sounds.JUMP, -14.0, _rng.randf_range(0.95, 1.1))
	if not grounded:
		_fall_speed = maxf(-character.velocity.y, 0.0)
	_was_grounded = grounded

	var speed: float = Vector2(character.velocity.x, character.velocity.z).length()
	if grounded and speed >= STEP_MIN_SPEED:
		_step_travel += speed * delta
		if _step_travel >= STEP_DISTANCE:
			_step_travel -= STEP_DISTANCE
			_footstep()
	elif grounded:
		# Parado: o próximo passo sai logo que voltar a andar.
		_step_travel = STEP_DISTANCE * 0.7


func _footstep() -> void:
	last_step_kind = FloorSurfaces.footstep_kind(get_tree(), character.global_position)
	var options: Array = Sounds.FOOTSTEPS[last_step_kind]
	var volume: float = OWN_STEP_DB if is_local() else OTHER_STEP_DB
	_play(options[_rng.randi() % options.size()], volume, _rng.randf_range(0.92, 1.08), 6.0)
	steps_played += 1


func _on_hit_received(result: ShotResult) -> void:
	if result.damage > 0.0:
		_play(Sounds.HURT, -4.0, _rng.randf_range(0.9, 1.1))


func _on_reload_started() -> void:
	# O jogador local ouve a recarga pelos braços em 1ª pessoa (ViewModel).
	if is_local() or character.weapon.data == null:
		return
	_play(character.weapon.data.reload_sound, -4.0, 1.0, 6.0)


func _on_rail_attached(_rail: SkylineRail) -> void:
	_play(Sounds.RAIL_HOOK, -6.0, _rng.randf_range(0.95, 1.05))
	_slide.pitch_scale = 0.8
	_slide.play()


func _update_slide() -> void:
	if not _slide.playing:
		return
	# Mais rápido = mais agudo e mais alto.
	var ratio: float = clampf(character.velocity.length() / maxf(character.rail_speed, 0.1), 0.0, 1.6)
	_slide.pitch_scale = lerpf(0.7, 1.25, clampf(ratio, 0.0, 1.0))
	_slide.volume_db = RAIL_SLIDE_DB + lerpf(-8.0, 0.0, clampf(ratio, 0.0, 1.0))


func _stop_slide() -> void:
	_slide.stop()
	_fall_speed = 0.0


func _play(stream: AudioStream, volume_db: float, pitch: float = 1.0, unit_size: float = 10.0) -> void:
	Sounds.play_3d(self, stream, global_position + Vector3.UP * 0.9, volume_db, pitch, unit_size)
