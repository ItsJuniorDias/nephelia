class_name BotDifficulty
extends Resource
## Configuração de dificuldade de um bot. Os presets ficam em bots/difficulty_*.tres.

@export var label: String = "Medium"
## Tempo entre ver um inimigo e começar a atirar.
@export_range(0.0, 2.0, 0.01, "suffix:s") var reaction_time: float = 0.35
## Tamanho do erro de mira (a mira "passeia" dentro deste ângulo em volta do alvo).
@export_range(0.0, 20.0, 0.1, "suffix:°") var aim_error_degrees: float = 3.0
## Rapidez para virar e mirar.
@export_range(30.0, 1080.0, 1.0, "suffix:°/s") var turn_speed_degrees: float = 300.0
## Só atira quando a mira está a menos deste ângulo do ponto que ele quer acertar.
@export_range(0.5, 20.0, 0.1, "suffix:°") var fire_tolerance_degrees: float = 3.0
@export_range(5.0, 100.0, 1.0, "suffix:m") var view_distance: float = 35.0
## Campo de visão (inimigos fora dele só são notados muito perto ou quando atiram no bot).
@export_range(30.0, 360.0, 1.0, "suffix:°") var field_of_view_degrees: float = 120.0
## Distância que o bot tenta manter do alvo durante o combate.
@export_range(2.0, 40.0, 0.5, "suffix:m") var preferred_distance: float = 10.0
## De quanto em quanto tempo troca o lado para onde anda de lado (esquiva).
@export_range(0.2, 5.0, 0.1, "suffix:s") var strafe_interval: float = 1.2
