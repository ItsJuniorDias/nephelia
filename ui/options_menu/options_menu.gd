class_name OptionsMenu
extends Control
## Tela de opções (sensibilidade do olhar, tamanho dos botões de toque, volume e música).
##
## Serve tanto no menu inicial quanto na pausa: aparece por cima, mexe direto no autoload
## `Settings` (que salva sozinho) e some ao voltar.

signal closed

@onready var sensitivity_slider: HSlider = $Panel/Rows/Sensitivity/Slider
@onready var sensitivity_value: Label = $Panel/Rows/Sensitivity/Value
@onready var buttons_slider: HSlider = $Panel/Rows/Buttons/Slider
@onready var buttons_value: Label = $Panel/Rows/Buttons/Value
@onready var volume_slider: HSlider = $Panel/Rows/Volume/Slider
@onready var volume_value: Label = $Panel/Rows/Volume/Value
@onready var music_slider: HSlider = $Panel/Rows/Music/Slider
@onready var music_value: Label = $Panel/Rows/Music/Value
@onready var back_button: Button = $Panel/Rows/BackButton


func _ready() -> void:
	sensitivity_slider.value = Settings.look_sensitivity
	buttons_slider.value = Settings.button_scale
	volume_slider.value = Settings.volume
	music_slider.value = Settings.music_volume
	sensitivity_slider.value_changed.connect(_on_slider_changed.bind(&"look_sensitivity"))
	buttons_slider.value_changed.connect(_on_slider_changed.bind(&"button_scale"))
	volume_slider.value_changed.connect(_on_slider_changed.bind(&"volume"))
	music_slider.value_changed.connect(_on_slider_changed.bind(&"music_volume"))
	back_button.pressed.connect(_on_back)
	_refresh_labels()


func open() -> void:
	visible = true
	back_button.grab_focus()


func _on_slider_changed(value: float, option: StringName) -> void:
	Settings.set_option(option, value)
	_refresh_labels()


func _on_back() -> void:
	visible = false
	closed.emit()


func _refresh_labels() -> void:
	sensitivity_value.text = "%d%%" % roundi(Settings.look_sensitivity * 100.0)
	buttons_value.text = "%d%%" % roundi(Settings.button_scale * 100.0)
	volume_value.text = "%d%%" % roundi(Settings.volume * 100.0)
	music_value.text = "%d%%" % roundi(Settings.music_volume * 100.0)
