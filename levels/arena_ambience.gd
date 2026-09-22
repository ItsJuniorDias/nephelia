class_name ArenaAmbience
extends Node
## Fundo sonoro da arena: vento no alto da cidade (mais forte no trilho e caindo) e a música da
## partida (ragtime ao piano, baixinho). Criado pelo ArenaSetup.

## Vento: volume parado e com o jogador rápido (trilho, queda).
const WIND_CALM_DB: float = -24.0
const WIND_FAST_DB: float = -8.0
## Velocidade em que o vento chega no máximo.
const WIND_FULL_SPEED: float = 18.0
const MUSIC_DB: float = -14.0

var wind: AudioStreamPlayer
var music: AudioStreamPlayer


func _ready() -> void:
	name = "ArenaAmbience"
	wind = AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = Sounds.WIND
	wind.bus = Sounds.SFX_BUS
	wind.volume_db = WIND_CALM_DB
	add_child(wind)
	wind.play()
	music = Sounds.music(self, Sounds.MUSIC_MATCH, MUSIC_DB)


func _process(delta: float) -> void:
	var player := _local_player()
	var speed: float = player.velocity.length() if player != null and player.is_alive else 0.0
	var goal: float = lerpf(WIND_CALM_DB, WIND_FAST_DB, clampf(speed / WIND_FULL_SPEED, 0.0, 1.0))
	wind.volume_db = move_toward(wind.volume_db, goal, delta * 30.0)


func _local_player() -> Character:
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.controller is HumanController:
			return character
	return null
