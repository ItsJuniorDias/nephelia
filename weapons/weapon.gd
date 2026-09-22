class_name Weapon
extends Node
## Arma de tiro instantâneo (hitscan): munição, ritmo de tiro e recarga.
##
## A arma só diz "atirei desta posição, nesta direção". Quem decide se acertou é o
## MatchReferee, o juiz da partida, que no multiplayer vai rodar no servidor.

signal fired(result: ShotResult)
signal reload_started
signal reload_finished
signal ammo_changed(ammo: int, magazine_size: int)

@export var weapon_name: String = "Revolver"
@export_range(1.0, 200.0, 1.0) var damage: float = 34.0
## Tempo mínimo entre tiros. Segurar o gatilho continua atirando nesse ritmo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var fire_interval: float = 0.35
@export_range(1, 100, 1) var magazine_size: int = 6
@export_range(0.1, 5.0, 0.05, "suffix:s") var reload_time: float = 1.6
@export_range(5.0, 500.0, 1.0, "suffix:m") var max_range: float = 80.0
## Imprecisão: cada tiro sai num cone aleatório deste tamanho.
@export_range(0.0, 10.0, 0.1, "suffix:°") var spread_degrees: float = 0.6

var ammo: int = 0
var is_reloading: bool = false
var character: Character

var _cooldown: float = 0.0
var _reload_timer: float = 0.0


## Chamado pelo personagem quando ele está pronto.
func setup(for_character: Character) -> void:
	character = for_character
	ammo = magazine_size


## Avança a arma um passo de física, obedecendo ao comando (atirar e recarregar).
func tick(delta: float, command: CharacterCommand) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	if command.reload:
		start_reload()
	if command.fire and not is_reloading and _cooldown <= 0.0:
		if ammo > 0:
			_fire(command)
		else:
			start_reload()


## Começa a recarregar (se não estiver cheia nem já recarregando).
func start_reload() -> void:
	if is_reloading or ammo >= magazine_size:
		return
	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit()


## Enche o tambor na hora, sem animação (respawn e testes).
func refill() -> void:
	is_reloading = false
	_cooldown = 0.0
	ammo = magazine_size
	ammo_changed.emit(ammo, magazine_size)


## Quanto da recarga já passou, de 0 a 1 (usado pela animação).
func get_reload_progress() -> float:
	if not is_reloading:
		return 0.0
	return clampf(1.0 - _reload_timer / reload_time, 0.0, 1.0)


func _finish_reload() -> void:
	is_reloading = false
	ammo = magazine_size
	reload_finished.emit()
	ammo_changed.emit(ammo, magazine_size)


func _fire(command: CharacterCommand) -> void:
	ammo -= 1
	_cooldown = fire_interval
	# Atirar tira a proteção de nascimento (não dá para atacar sendo imortal).
	character.end_spawn_protection()
	# O tiro sai do olho, na direção para onde a cabeça aponta (é o que a mira mostra).
	var origin: Vector3 = character.head.global_position
	var direction: Vector3 = -character.head.global_basis.z
	var referee: MatchReferee = MatchReferee.find(character)
	var result: ShotResult
	if referee != null:
		result = referee.resolve_shot(character, self, origin, direction, command.aim_assist)
	else:
		result = ShotResult.new()
		result.shooter = character
		result.weapon = self
		result.origin = origin
		result.direction = direction
		result.end_point = origin + direction * max_range
	ammo_changed.emit(ammo, magazine_size)
	fired.emit(result)
	# Tambor vazio: já começa a recarregar sozinho (menos um botão para o dedão).
	if ammo == 0:
		start_reload()
