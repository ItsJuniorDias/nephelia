class_name Sounds
extends RefCounted
## Os sons do jogo num lugar só, e atalhos para tocar um som solto no canal certo.
##
## Canais (`default_bus_layout.tres`, feito por `tools/make_audio_buses.gd`): "Music", "SFX"
## (tiros, passos, trilho, vento) e "UI" (cliques e avisos). Os arquivos saem de
## `tools/prepare_sounds.py` (origem e licença de cada um: CREDITS.md).

const SFX_BUS: StringName = &"SFX"
const UI_BUS: StringName = &"UI"
const MUSIC_BUS: StringName = &"Music"

const FOOTSTEPS: Dictionary[StringName, Array] = {
	&"concrete": [
		preload("res://assets/audio/sfx/kenney/footstep_concrete_000.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_concrete_001.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_concrete_002.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_concrete_003.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_concrete_004.ogg"),
	],
	&"grass": [
		preload("res://assets/audio/sfx/kenney/footstep_grass_000.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_grass_001.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_grass_002.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_grass_003.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_grass_004.ogg"),
	],
	&"wood": [
		preload("res://assets/audio/sfx/kenney/footstep_wood_000.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_wood_001.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_wood_002.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_wood_003.ogg"),
		preload("res://assets/audio/sfx/kenney/footstep_wood_004.ogg"),
	],
}
const JUMP: AudioStream = preload("res://assets/audio/sfx/kenney/impactSoft_medium_000.ogg")
const LAND: AudioStream = preload("res://assets/audio/sfx/kenney/impactSoft_heavy_000.ogg")
const HURT: AudioStream = preload("res://assets/audio/sfx/kenney/impactPunch_heavy_000.ogg")
const DEATH: AudioStream = preload("res://assets/audio/sfx/kenney/impactPunch_medium_000.ogg")
const RAIL_HOOK: AudioStream = preload("res://assets/audio/sfx/kenney/impactMetal_heavy_000.ogg")
const RAIL_SLIDE: AudioStream = preload("res://assets/audio/sfx/nephelia/rail_slide_loop.wav")
const WIND: AudioStream = preload("res://assets/audio/sfx/opengameart/wind_loop.ogg")
const HIT_CONFIRM: AudioStream = preload("res://assets/audio/sfx/kenney/tick_002.ogg")
const KILL_CONFIRM: AudioStream = preload("res://assets/audio/sfx/kenney/confirmation_001.ogg")
const MATCH_END: AudioStream = preload("res://assets/audio/sfx/kenney/impactBell_heavy_000.ogg")
const UI_CLICK: AudioStream = preload("res://assets/audio/sfx/kenney/click_002.ogg")
const UI_BACK: AudioStream = preload("res://assets/audio/sfx/kenney/back_001.ogg")
## Ragtime do começo do século XX (domínio público): banda de 1906 no menu, piano na partida.
const MUSIC_MENU: AudioStream = preload("res://assets/audio/music/maple_leaf_rag_marine_band_1906.ogg")
const MUSIC_MATCH: AudioStream = preload("res://assets/audio/music/maple_leaf_rag_piano.ogg")


## Toca um som solto num ponto do mundo (some sozinho quando acaba).
static func play_3d(parent: Node, stream: AudioStream, at: Vector3, volume_db: float = 0.0,
		pitch: float = 1.0, unit_size: float = 10.0) -> AudioStreamPlayer3D:
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = unit_size
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Toca um som solto sem posição (interface, avisos para o próprio jogador).
static func play_2d(parent: Node, stream: AudioStream, volume_db: float = 0.0, bus: StringName = UI_BUS,
		pitch: float = 1.0) -> AudioStreamPlayer:
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch
	# Toca mesmo com o jogo pausado (menus de pausa e de fim de partida).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Música de fundo em loop (um nó que fica na cena).
static func music(parent: Node, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.stream = stream
	player.bus = MUSIC_BUS
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.play()
	return player


## Liga um som de clique em todos os botões dentro de `root` (o botão "voltar" tem outro som).
static func wire_buttons(root: Node) -> void:
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var is_back: bool = String(button.name).to_lower().contains("back") \
				or String(button.name).to_lower().contains("resume")
		button.pressed.connect(func() -> void:
			play_2d(root, UI_BACK if is_back else UI_CLICK, -4.0))
