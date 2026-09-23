class_name Weapon
extends Node
## Arma de tiro instantâneo (hitscan): munição, ritmo de tiro e recarga.
##
## A arma só diz "atirei desta posição, nesta direção". Quem decide se acertou é o
## MatchReferee, o juiz da partida, que no multiplayer vai rodar no servidor.
##
## O nó é sempre o mesmo: pegar um item de arma só troca a FICHA (`WeaponData`) dele. As armas
## de item têm munição contada (tambor + reserva); quando acaba tudo, o personagem volta
## sozinho para o revólver, que nunca acaba.

signal fired(result: ShotResult)
## O tiro causou dano em alguém (sozinho: na hora; no cliente do multiplayer: quando o anfitrião
## confirma). O HUD mostra o marcador de acerto.
signal hit_confirmed(result: ShotResult)
signal reload_started
signal reload_finished
signal ammo_changed(ammo: int, magazine_size: int)
## Trocou de arma (pegou um item ou acabou a munição).
signal weapon_changed(data: WeaponData)

## Ficha da arma em uso; os valores abaixo são cópias dela (dá para ajustar num teste).
var data: WeaponData
var weapon_name: String = "Revolver"
var damage: float = 34.0
var fire_interval: float = 0.35
var magazine_size: int = 6
var reload_time: float = 1.6
var max_range: float = 80.0
var spread_degrees: float = 0.6
var pellets: int = 1

var ammo: int = 0
## Munição fora do tambor (-1 = infinita).
var reserve: int = -1
var is_reloading: bool = false
var character: Character

var _cooldown: float = 0.0
var _reload_timer: float = 0.0
var _reload_duration: float = 1.0
## Arma que entra quando esta "recarga" acabar (troca por falta de munição).
var _pending_weapon: WeaponData


## Chamado pelo personagem quando ele está pronto.
func setup(for_character: Character) -> void:
	character = for_character
	equip(WeaponCatalog.default_weapon())


## Troca a arma (item pego, munição no fim ou respawn): tambor e reserva cheios.
func equip(new_data: WeaponData) -> void:
	data = new_data
	weapon_name = data.weapon_name
	damage = data.damage
	fire_interval = data.fire_interval
	magazine_size = data.magazine_size
	reload_time = data.reload_time
	max_range = data.max_range
	spread_degrees = data.spread_degrees
	pellets = data.pellets
	ammo = magazine_size
	reserve = data.reserve_ammo
	is_reloading = false
	_cooldown = 0.0
	_pending_weapon = null
	weapon_changed.emit(data)
	ammo_changed.emit(ammo, magazine_size)


## É a arma de sempre (revólver), e não uma pega na arena.
func is_default() -> bool:
	return data != null and data.id == WeaponCatalog.DEFAULT_ID


## Tambor e reserva cheios (não vale a pena pegar de novo).
func is_full() -> bool:
	return data != null and ammo >= magazine_size and reserve >= data.reserve_ammo


## Avança a arma um passo de física, obedecendo ao comando (atirar e recarregar).
func tick(delta: float, command: CharacterCommand) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	# Arma da arena sem munição nenhuma: o personagem guarda e volta para o revólver, mesmo
	# que nunca mais aperte o gatilho.
	if ammo == 0 and reserve == 0 and not is_default():
		_start_swap_to_default()

	if command.reload:
		start_reload()
	if command.fire and not is_reloading and _cooldown <= 0.0:
		if ammo > 0:
			_fire(command)
		else:
			_handle_empty()


## Começa a recarregar (se não estiver cheia, já recarregando, nem sem reserva).
func start_reload() -> void:
	if is_reloading or ammo >= magazine_size or reserve == 0:
		return
	is_reloading = true
	_reload_duration = reload_time
	_reload_timer = reload_time
	reload_started.emit()


## Volta para o revólver cheio, sem animação (respawn e testes).
func refill() -> void:
	equip(WeaponCatalog.default_weapon())


## Munição vinda do anfitrião (multiplayer: corrige a previsão do cliente).
func set_ammo(new_ammo: int, new_reserve: int) -> void:
	ammo = clampi(new_ammo, 0, magazine_size)
	reserve = new_reserve
	ammo_changed.emit(ammo, magazine_size)


## Quanto da recarga já passou, de 0 a 1 (usado pela animação).
func get_reload_progress() -> float:
	if not is_reloading:
		return 0.0
	return clampf(1.0 - _reload_timer / _reload_duration, 0.0, 1.0)


# Tambor vazio: recarrega, ou guarda a arma se não sobrou munição nenhuma.
func _handle_empty() -> void:
	if reserve == 0 and not is_default():
		_start_swap_to_default()
	else:
		start_reload()


# Acabou a munição da arma pega: o personagem guarda ela e saca o revólver (leva o tempo de
# uma recarga, então o HUD e as mãos mostram a troca do mesmo jeito).
func _start_swap_to_default() -> void:
	if is_reloading:
		return
	_pending_weapon = WeaponCatalog.default_weapon()
	is_reloading = true
	_reload_duration = _pending_weapon.reload_time
	_reload_timer = _reload_duration
	reload_started.emit()


func _finish_reload() -> void:
	is_reloading = false
	if _pending_weapon != null:
		equip(_pending_weapon)
		reload_finished.emit()
		return
	if reserve < 0:
		ammo = magazine_size
	else:
		# Tira da reserva só o que cabe no tambor.
		var taken: int = mini(magazine_size - ammo, reserve)
		ammo += taken
		reserve -= taken
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
	# Na rede o sorteio da imprecisão sai do número do comando: o cliente desenha o mesmo tiro
	# que o anfitrião decide.
	var seed: int = -1 if command.tick < 0 else absi(hash([character.net_id, command.tick]))
	if referee != null:
		result = referee.resolve_shot(character, self, origin, direction, command.aim_assist, seed)
	else:
		result = ShotResult.new()
		result.shooter = character
		result.weapon = self
		result.origin = origin
		result.direction = direction
		result.end_point = origin + direction * max_range
	ammo_changed.emit(ammo, magazine_size)
	fired.emit(result)
	if result.victim != null and result.damage > 0.0:
		hit_confirmed.emit(result)
	# Tambor vazio: já recarrega (ou troca de arma) sozinho, menos um botão para o dedão.
	if ammo == 0:
		_handle_empty()
