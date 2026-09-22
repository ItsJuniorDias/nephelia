class_name Powers
extends Node
## Poderes do personagem e a energia que eles gastam (nó filho do Character, como a arma).
##
## São dois: a Faísca (descarga elétrica de perto, tira vida) e a Rajada (sopro que empurra os
## inimigos, bom para jogar alguém para fora da ilha). Aqui só cuidamos da energia e do ritmo;
## quem decide quem foi atingido é o MatchReferee, como nos tiros.

signal energy_changed(energy: float, max_energy: float)
signal power_used(result: PowerResult)

@export_group("Energia")
@export_range(10.0, 500.0, 5.0) var max_energy: float = 100.0
## Energia que volta por segundo.
@export_range(1.0, 100.0, 1.0) var regeneration: float = 14.0
## Tempo parado (sem usar poder) antes de a energia começar a voltar.
@export_range(0.0, 5.0, 0.1, "suffix:s") var regeneration_delay: float = 1.2

@export_group("Faísca")
@export_range(0.0, 100.0, 1.0) var spark_cost: float = 30.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var spark_interval: float = 0.7
@export_range(1.0, 100.0, 1.0) var spark_damage: float = 28.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var spark_range: float = 24.0

@export_group("Rajada")
@export_range(0.0, 100.0, 1.0) var gust_cost: float = 45.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var gust_interval: float = 1.4
@export_range(0.0, 100.0, 1.0) var gust_damage: float = 12.0
@export_range(1.0, 20.0, 0.5, "suffix:m") var gust_range: float = 7.5
@export_range(10.0, 180.0, 5.0, "suffix:°") var gust_angle_degrees: float = 65.0
## Empurrão: para longe de quem soprou e para cima (tira o inimigo do chão).
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var gust_push: float = 11.0
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var gust_lift: float = 5.0

var energy: float = 0.0
var character: Character

var _spark_cooldown: float = 0.0
var _gust_cooldown: float = 0.0
var _regeneration_timer: float = 0.0
var _was_spark_held: bool = false
var _was_gust_held: bool = false


## Chamado pelo personagem quando ele está pronto.
func setup(for_character: Character) -> void:
	character = for_character
	energy = max_energy


## Avança um passo de física obedecendo ao comando (usar poderes) e devolve energia.
func tick(delta: float, command: CharacterCommand) -> void:
	_spark_cooldown = maxf(_spark_cooldown - delta, 0.0)
	_gust_cooldown = maxf(_gust_cooldown - delta, 0.0)
	_regeneration_timer = maxf(_regeneration_timer - delta, 0.0)
	if _regeneration_timer <= 0.0 and energy < max_energy:
		_set_energy(energy + regeneration * delta)

	# O comando diz se o botão está apertado; o poder sai no instante em que aperta.
	var spark_pressed: bool = command.spark and not _was_spark_held
	_was_spark_held = command.spark
	var gust_pressed: bool = command.gust and not _was_gust_held
	_was_gust_held = command.gust

	if spark_pressed and can_use_spark():
		_use_spark(command)
	elif gust_pressed and can_use_gust():
		_use_gust()


func can_use_spark() -> bool:
	return character.is_alive and _spark_cooldown <= 0.0 and energy >= spark_cost


func can_use_gust() -> bool:
	return character.is_alive and _gust_cooldown <= 0.0 and energy >= gust_cost


## Enche a energia na hora (respawn e testes).
func refill() -> void:
	_spark_cooldown = 0.0
	_gust_cooldown = 0.0
	_regeneration_timer = 0.0
	_set_energy(max_energy)


func _use_spark(command: CharacterCommand) -> void:
	_spend(spark_cost)
	_spark_cooldown = spark_interval
	var referee: MatchReferee = MatchReferee.find(character)
	if referee == null:
		return
	power_used.emit(referee.resolve_spark(character, self, command.aim_assist))


func _use_gust() -> void:
	_spend(gust_cost)
	_gust_cooldown = gust_interval
	var referee: MatchReferee = MatchReferee.find(character)
	if referee == null:
		return
	power_used.emit(referee.resolve_gust(character, self))


func _spend(amount: float) -> void:
	# Usar um poder tira a proteção de nascimento (não dá para atacar sendo imortal).
	character.end_spawn_protection()
	_set_energy(energy - amount)
	_regeneration_timer = regeneration_delay


func _set_energy(value: float) -> void:
	energy = clampf(value, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
