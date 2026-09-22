class_name Settings
extends Object
## Opções do jogador, guardadas no aparelho (`user://settings.cfg`) e aplicadas na hora.
##
## É uma classe só de membros estáticos, e não um autoload: no modo de teste do Godot
## (`-s <script>`) o nome de um autoload não é reconhecido pelo compilador, mas um `class_name`
## é. Quem usa cada valor:
##   sensibilidade e tamanho dos botões -> player/human_controller.gd e ui/touch_controls
##   volume e volume da música -> canais de áudio "Master" e "Music", aqui mesmo
##   dificuldade -> levels/arena_setup.gd, ao abrir a arena

const FILE := "user://settings.cfg"
const DIFFICULTIES: Array[StringName] = [&"easy", &"medium", &"hard"]
## Nome de cada dificuldade na tela.
const DIFFICULTY_LABELS: Dictionary = {
	&"easy": "FÁCIL", &"medium": "MÉDIO", &"hard": "DIFÍCIL",
}

## Multiplicador da sensibilidade do olhar (1 = o que o jogo traz de fábrica).
static var look_sensitivity: float = 1.0
## Multiplicador do tamanho dos botões de toque.
static var button_scale: float = 1.0
## Volume geral, de 0 a 1.
static var volume: float = 0.8
## Volume da música (em cima do geral), de 0 a 1.
static var music_volume: float = 0.6
static var difficulty: StringName = &"medium"
## Sobe a cada mudança: quem precisa reagir (os botões de toque) compara com a versão que já aplicou.
static var version: int = 0


# Roda uma vez, quando a classe é carregada.
static func _static_init() -> void:
	load_settings()


static func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(FILE) == OK:
		look_sensitivity = clampf(file.get_value("controls", "look_sensitivity", look_sensitivity), 0.3, 3.0)
		button_scale = clampf(file.get_value("controls", "button_scale", button_scale), 0.7, 1.6)
		volume = clampf(file.get_value("audio", "volume", volume), 0.0, 1.0)
		music_volume = clampf(file.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
		var saved := StringName(file.get_value("game", "difficulty", difficulty))
		difficulty = saved if saved in DIFFICULTIES else difficulty
	_apply_volume()
	version += 1


static func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("controls", "look_sensitivity", look_sensitivity)
	file.set_value("controls", "button_scale", button_scale)
	file.set_value("audio", "volume", volume)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("game", "difficulty", String(difficulty))
	file.save(FILE)


## Muda uma opção, aplica, salva e avisa (pela `version`) quem precisa reagir.
static func set_option(option: StringName, value: Variant) -> void:
	match option:
		&"look_sensitivity":
			look_sensitivity = clampf(value, 0.3, 3.0)
		&"button_scale":
			button_scale = clampf(value, 0.7, 1.6)
		&"volume":
			volume = clampf(value, 0.0, 1.0)
			_apply_volume()
		&"music_volume":
			music_volume = clampf(value, 0.0, 1.0)
			_apply_volume()
		&"difficulty":
			difficulty = value if value in DIFFICULTIES else difficulty
	version += 1
	save_settings()


## Próxima dificuldade da lista (o botão do menu gira entre elas).
static func next_difficulty() -> void:
	var index: int = DIFFICULTIES.find(difficulty)
	set_option(&"difficulty", DIFFICULTIES[(index + 1) % DIFFICULTIES.size()])


static func difficulty_label() -> String:
	return DIFFICULTY_LABELS.get(difficulty, "MÉDIO")


## Recurso de dificuldade dos bots correspondente à opção escolhida.
static func difficulty_resource() -> BotDifficulty:
	return load("res://bots/difficulty_%s.tres" % difficulty) as BotDifficulty


static func _apply_volume() -> void:
	_set_bus_volume(&"Master", volume)
	_set_bus_volume(&"Music", music_volume)


static func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))
