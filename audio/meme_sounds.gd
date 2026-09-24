class_name MemeSounds
extends Node
## Sons de meme por cima da partida (pedido do usuário, 2026-09-24): só enfeite, não muda o jogo.
## Criado pelo ArenaSetup; a opção FUNNY SOUNDS (`Settings.funny_sounds`) desliga tudo.
##
## Tudo vem dos sinais que o jogo já emite (juiz, partida, arma do jogador local) e da posição dos
## personagens, então funciona igual no multiplayer. Sons em `assets/audio/sfx/memes/`, feitos por
## `tools/make_meme_sounds.py` (sintetizados aqui + trechos CC0 do Freesound, ver CREDITS.md).
##
## Quando toca:
##   início da partida = gongo; faltam 30 s = "dun dun DUNNN"
##   você: tiro na cabeça que elimina = boom; na cabeça sem matar = bonk (às vezes);
##     elimina de longe ou pendurado no trilho = plateia "oooh"; 3 abates seguidos = buzina
##     (e a cada 2 a mais); morre depois de 3+ abates seguidos = arranhão de disco + imagem
##     congelada ("Yep, that's me."); morre 3 vezes seguidas sem eliminar ninguém = marcha fúnebre;
##     erra um tambor inteiro = grilos; pega arma = "ka-ching"; recarrega cheio ou atira
##     recarregando = bipe de erro; pula = boing (raro); vence = fanfarra de kazoo; último =
##     trombone triste
##   qualquer um: cai da ilha = apito de desenho (no ar); bot cai sozinho = risada de plateia;
##     cai logo depois de renascer = "ba dum tss"; aterrissa de muito alto = cano de metal (às vezes)

const BOOM: AudioStream = preload("res://assets/audio/sfx/memes/meme_boom.wav")
const BONK: AudioStream = preload("res://assets/audio/sfx/memes/meme_bonk.wav")
const SAD_TROMBONE: AudioStream = preload("res://assets/audio/sfx/memes/meme_sad_trombone.wav")
const FALL_WHISTLE: AudioStream = preload("res://assets/audio/sfx/memes/meme_fall_whistle.wav")
const AIRHORN: AudioStream = preload("res://assets/audio/sfx/memes/meme_airhorn.wav")
const RECORD_SCRATCH: AudioStream = preload("res://assets/audio/sfx/memes/meme_record_scratch.wav")
const RIMSHOT: AudioStream = preload("res://assets/audio/sfx/memes/meme_rimshot.wav")
const DUN_DUN: AudioStream = preload("res://assets/audio/sfx/memes/meme_dun_dun.wav")
const KAZOO_FANFARE: AudioStream = preload("res://assets/audio/sfx/memes/meme_kazoo_fanfare.wav")
const ERROR: AudioStream = preload("res://assets/audio/sfx/memes/meme_error.wav")
const MODEM: AudioStream = preload("res://assets/audio/sfx/memes/meme_modem.wav")
const GONG: AudioStream = preload("res://assets/audio/sfx/memes/meme_gong.wav")
const FUNERAL_MARCH: AudioStream = preload("res://assets/audio/sfx/memes/meme_funeral_march.wav")
const BOING: AudioStream = preload("res://assets/audio/sfx/memes/meme_boing.wav")
const METAL_PIPE: AudioStream = preload("res://assets/audio/sfx/memes/meme_metal_pipe.wav")
const KA_CHING: AudioStream = preload("res://assets/audio/sfx/memes/meme_ka_ching.wav")
const CROWD_OOH: AudioStream = preload("res://assets/audio/sfx/memes/meme_crowd_ooh.wav")
const LAUGHS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/memes/meme_laugh_1.wav"),
	preload("res://assets/audio/sfx/memes/meme_laugh_2.wav"),
]
const CRICKETS: AudioStream = preload("res://assets/audio/sfx/memes/meme_crickets.wav")

## Abate a partir desta distância (m) faz a plateia dizer "oooh".
const LONG_SHOT_DISTANCE: float = 30.0
## Abates seguidos (sem morrer) que tocam a buzina; depois, a cada `STREAK_STEP` a mais.
const STREAK_AIRHORN: int = 3
const STREAK_STEP: int = 2
## Mortes seguidas sem eliminar ninguém que tocam a marcha fúnebre.
const DEATHS_FOR_FUNERAL: int = 3
## Caindo abaixo desta altura (m) e mais rápido que isto (m/s) = caiu da ilha (as ilhas ficam
## entre -1 e 1 m; nada anda abaixo de -2).
const FALL_ALTITUDE: float = -5.0
const FALL_SPEED: float = 6.0
## Aterrissagem mais rápida que isto (m/s, na vertical) = "de muito alto".
const BIG_LANDING_SPEED: float = 12.0
## Morrer caindo até este tempo (s) depois de renascer = "ba dum tss".
const RESPAWN_FALL_WINDOW: float = 5.0
## Tiro acima de (altura do olho - isto) é na cabeça.
const HEAD_MARGIN: float = 0.25
## Espera o resultado de um tiro na cabeça (no cliente o abate chega pela rede).
const KILL_SETTLE_TIME: float = 0.15
## Chances dos sons que se repetiriam demais.
const BONK_CHANCE: float = 0.7
const BOING_CHANCE: float = 0.06
const METAL_PIPE_CHANCE: float = 0.5
const LAUGH_CHANCE: float = 0.8
## Dois sons de meme "comentando" (sem posição) não saem colados um no outro.
const COMMENT_GAP: float = 0.35

var player: Character
var referee: MatchReferee
var deathmatch: Deathmatch

var _clock: float = 0.0
var _last_comment: float = -INF
var _streak: int = 0
var _deaths_in_row: int = 0
var _shots_without_hit: int = 0
var _last_head_victim: Character
var _last_head_time: float = -INF
var _gong_pending: bool = true
var _dun_done: bool = false
var _reload_complained: bool = false
var _falling: Dictionary[Character, bool] = {}
var _air_speed: Dictionary[Character, float] = {}
var _was_grounded: Dictionary[Character, bool] = {}
var _respawned_at: Dictionary[Character, float] = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "MemeSounds"
	_rng.randomize()
	# Juiz, partida e jogador ficam prontos depois deste nó: conecta no fim do quadro.
	_connect.call_deferred()


func _connect() -> void:
	referee = MatchReferee.find(self)
	deathmatch = Deathmatch.find(self)
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.controller is HumanController:
			player = character
	if referee != null:
		referee.character_died.connect(_on_character_died)
		referee.character_respawned.connect(_on_character_respawned)
		referee.item_picked.connect(_on_item_picked)
	if deathmatch != null:
		deathmatch.match_started.connect(_on_match_started)
		deathmatch.match_finished.connect(_on_match_finished)
	if player != null and player.weapon != null:
		player.weapon.fired.connect(_on_player_fired)
		player.weapon.hit_confirmed.connect(_on_player_hit_confirmed)


static func is_enabled() -> bool:
	return Settings.funny_sounds


func _process(delta: float) -> void:
	_clock += delta
	if deathmatch != null and not deathmatch.waiting and not deathmatch.is_finished:
		if _gong_pending and _clock > 0.6:
			_gong_pending = false
			_comment(GONG, -3.0, true)
		if not _dun_done and deathmatch.time_left <= 30.0 and deathmatch.time_left > 25.0:
			_dun_done = true
			_comment(DUN_DUN, 0.0, true)
	_check_player_input()


func _physics_process(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		_watch_body(node as Character)


# Quedas da ilha, aterrissagens de muito alto e pulos (o boing é só do jogador local).
func _watch_body(character: Character) -> void:
	if not character.is_alive:
		_was_grounded[character] = true
		_air_speed[character] = 0.0
		return
	if character.is_on_rail:
		_was_grounded[character] = false
		_air_speed[character] = 0.0
		return
	var grounded: bool = character.is_grounded()
	var was_grounded: bool = _was_grounded.get(character, true)
	if not grounded:
		_air_speed[character] = maxf(_air_speed.get(character, 0.0), -character.velocity.y)
		if not _falling.get(character, false) and character.global_position.y < FALL_ALTITUDE \
				and character.velocity.y < -FALL_SPEED:
			_falling[character] = true
			_play_at(character, FALL_WHISTLE, 2.0)
		if was_grounded and character == player and character.velocity.y > 1.0 \
				and _rng.randf() < BOING_CHANCE:
			_comment(BOING, -4.0)
	elif not was_grounded:
		if _air_speed.get(character, 0.0) > BIG_LANDING_SPEED and _rng.randf() < METAL_PIPE_CHANCE:
			_play_at(character, METAL_PIPE, 0.0)
		_air_speed[character] = 0.0
		_falling[character] = false
	_was_grounded[character] = grounded


# Recarregar com a arma cheia ou apertar o gatilho recarregando: bipe de erro (uma vez por recarga).
func _check_player_input() -> void:
	if player == null or not player.is_alive or player.weapon == null:
		return
	var weapon: Weapon = player.weapon
	if Input.is_action_just_pressed(&"reload") and weapon.ammo >= weapon.magazine_size:
		_comment(ERROR, -6.0)
	if not weapon.is_reloading:
		_reload_complained = false
	elif Input.is_action_just_pressed(&"fire") and not _reload_complained:
		_reload_complained = true
		_comment(ERROR, -6.0)


func _on_player_fired(_result: ShotResult) -> void:
	_shots_without_hit += 1
	var magazine: int = player.weapon.magazine_size
	if magazine >= 4 and _shots_without_hit >= magazine:
		_shots_without_hit = 0
		_comment(CRICKETS, -2.0)


func _on_player_hit_confirmed(result: ShotResult) -> void:
	_shots_without_hit = 0
	var victim: Character = result.victim
	if victim == null or victim == player or not is_headshot(result.end_point, victim):
		return
	_last_head_victim = victim
	_last_head_time = _clock
	get_tree().create_timer(KILL_SETTLE_TIME).timeout.connect(_after_headshot.bind(victim))


# Tiro na cabeça que não matou: bonk (o que matou toca o boom em `_after_kill`).
func _after_headshot(victim: Character) -> void:
	if is_instance_valid(victim) and victim.is_alive and _rng.randf() < BONK_CHANCE:
		_comment(BONK, -2.0)


## O ponto do tiro pegou na cabeça de `victim` (acima do olho menos uma folga).
static func is_headshot(point: Vector3, victim: Character) -> bool:
	return point.y > victim.head.global_position.y - HEAD_MARGIN


func _on_character_died(victim: Character, killer: Character) -> void:
	var fell: bool = referee != null and victim.global_position.y < referee.fall_limit_y + 2.0
	var just_respawned: bool = _clock - _respawned_at.get(victim, -INF) < RESPAWN_FALL_WINDOW
	if victim == player:
		var had_streak: bool = _streak >= STREAK_AIRHORN
		_streak = 0
		_deaths_in_row += 1
		if had_streak:
			_comment(RECORD_SCRATCH, 0.0, true)
			if is_enabled():
				_freeze_frame()
		elif _deaths_in_row >= DEATHS_FOR_FUNERAL:
			_deaths_in_row = 0
			_comment(FUNERAL_MARCH, -2.0, true)
		elif fell and just_respawned:
			_comment(RIMSHOT, -2.0, true)
	else:
		if killer == player and player != null:
			_streak += 1
			_deaths_in_row = 0
			get_tree().create_timer(KILL_SETTLE_TIME).timeout.connect(_after_kill.bind(victim))
		elif fell and just_respawned:
			_comment(RIMSHOT, -3.0)
		elif fell and killer == null and _rng.randf() < LAUGH_CHANCE:
			_comment(LAUGHS[_rng.randi() % LAUGHS.size()], -3.0)
	_falling.erase(victim)


func _after_kill(victim: Character) -> void:
	if not is_instance_valid(victim) or player == null:
		return
	if _streak >= STREAK_AIRHORN and (_streak - STREAK_AIRHORN) % STREAK_STEP == 0:
		_comment(AIRHORN, -2.0, true)
	elif victim == _last_head_victim and _clock - _last_head_time < KILL_SETTLE_TIME + 0.4:
		_comment(BOOM, 0.0, true)
	elif player.is_on_rail or player.global_position.distance_to(victim.global_position) >= LONG_SHOT_DISTANCE:
		_comment(CROWD_OOH, -2.0, true)


func _on_character_respawned(character: Character) -> void:
	_respawned_at[character] = _clock
	_falling[character] = false


func _on_item_picked(character: Character, pickup: Pickup) -> void:
	if character == player and Pickup.weapon_id_of(pickup.kind) != &"":
		_comment(KA_CHING, -3.0)


func _on_match_started() -> void:
	_streak = 0
	_deaths_in_row = 0
	_shots_without_hit = 0
	_dun_done = false
	_gong_pending = true
	_clock = maxf(_clock, 1.0)


func _on_match_finished(ranking: Array[Dictionary]) -> void:
	if player == null or ranking.size() < 2:
		return
	if ranking[0]["character"] == player and not deathmatch.is_draw():
		_comment(KAZOO_FANFARE, -1.0, true)
	elif ranking[ranking.size() - 1]["character"] == player:
		_comment(SAD_TROMBONE, -1.0, true)


## Som "comentando" a partida, sem posição. `important` passa por cima do intervalo mínimo.
func _comment(stream: AudioStream, volume_db: float = 0.0, important: bool = false) -> AudioStreamPlayer:
	if not is_enabled():
		return null
	if not important and _clock - _last_comment < COMMENT_GAP:
		return null
	_last_comment = _clock
	return Sounds.play_2d(self, stream, volume_db, Sounds.SFX_BUS)


# No próprio jogador, sem posição; nos outros, vindo de onde eles estão.
func _play_at(character: Character, stream: AudioStream, volume_db: float) -> Node:
	if not is_enabled():
		return null
	if character == player:
		return Sounds.play_2d(self, stream, volume_db, Sounds.SFX_BUS)
	return Sounds.play_3d(self, stream, character.global_position, volume_db + 4.0, 1.0, 14.0)


# "Yep, that's me.": a tela congela por um instante (a última imagem desenhada, amarelada).
func _freeze_frame() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.name = "FreezeFrame"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var picture := TextureRect.new()
	picture.texture = ImageTexture.create_from_image(image)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.modulate = Color(1.0, 0.92, 0.78)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(picture)
	var caption := Label.new()
	caption.text = "Yep, that's me."
	caption.theme_type_variation = &"Title"
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.position += Vector2(48.0, -120.0)
	layer.add_child(caption)
	add_child(layer)
	get_tree().create_timer(1.2, true, false, true).timeout.connect(layer.queue_free)


## Modem discado ao entrar numa partida do Wi-Fi (chamado pela sala do multiplayer).
static func play_joining(parent: Node) -> void:
	if is_enabled():
		Sounds.play_2d(parent, MODEM, -6.0, Sounds.UI_BUS)
