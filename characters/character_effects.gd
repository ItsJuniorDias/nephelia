class_name CharacterEffects
extends Node3D
## Efeitos visuais de um personagem: faíscas do gancho raspando no trilho, poeira ao cair de uma
## altura, a fumaça em que o corpo some quando ele renasce e o anel dourado onde ele nasce.
##
## Só escuta o Character (sinais e velocidade), como o CharacterAudio: não muda nada no jogo.
## Criado em código pelo Character (nó guardado em cena instanciada some no build do iPhone).

## Queda mais rápida que isto levanta poeira (a do som é mais baixa: pulinho não faz poeira).
const LAND_DUST_SPEED: float = 6.0
## Velocidade mínima no trilho para sair faísca (sendo puxado até ele não conta).
const SPARK_MIN_SPEED: float = 2.0

var character: Character

var _sparks: CPUParticles3D
var _was_grounded: bool = true
var _fall_speed: float = 0.0
var _body_left_at: Vector3 = Vector3.ZERO
var _body_lying: bool = false


## Chamado pelo Character quando ele está pronto.
func setup(for_character: Character) -> void:
	character = for_character
	name = "CharacterEffects"
	character.died.connect(_on_died)
	character.respawned.connect(_on_respawned)
	_sparks = Vfx.rail_sparks()
	add_child(_sparks)


func is_sparking() -> bool:
	return _sparks != null and _sparks.emitting


func _physics_process(_delta: float) -> void:
	if character == null or not character.is_alive:
		_sparks.emitting = false
		_was_grounded = true
		return
	var sliding: bool = character.is_on_rail and not character.is_rail_pulling \
			and character.velocity.length() > SPARK_MIN_SPEED
	_sparks.emitting = sliding
	if sliding:
		# O gancho fica no trilho, bem acima da cabeça.
		_sparks.global_position = character.global_position + Vector3.UP * Character.RAIL_HANG
	if character.is_on_rail:
		_was_grounded = false
		_fall_speed = 0.0
		return
	var grounded: bool = character.is_grounded()
	if grounded and not _was_grounded and _fall_speed > LAND_DUST_SPEED:
		var strength: float = clampf((_fall_speed - LAND_DUST_SPEED) / 8.0, 0.0, 1.0)
		Vfx.landing_dust(_world(), character.global_position, strength)
	if not grounded:
		_fall_speed = maxf(-character.velocity.y, 0.0)
	_was_grounded = grounded


func _on_died(_killer: Character) -> void:
	# O corpo fica deitado ali até o personagem renascer; aí some numa nuvem.
	_body_left_at = character.global_position
	_body_lying = true


func _on_respawned() -> void:
	if _body_lying:
		Vfx.death_poof(_world(), _body_left_at)
		_body_lying = false
	Vfx.spawn_ring(_world(), character.global_position)
	_was_grounded = true
	_fall_speed = 0.0


# Os efeitos ficam no mundo (a fumaça não pode andar junto com o personagem).
func _world() -> Node:
	return character.get_parent()
