extends Node3D
## Fase de teste (greybox): ilha flutuante para experimentar o movimento do jogador.
## A arte é provisória (formas CSG com cores lisas); os assets de verdade vêm depois.
## A escada (Props/Staircase) tem uma rampa de colisão invisível (StairsRamp):
## o CharacterBody3D não sobe degraus sozinho, e a rampa deixa a subida suave.

## Abaixo desta altura o jogador "caiu da ilha" e volta para o ponto de nascimento.
@export var fall_limit_y: float = -30.0

@onready var player: Player = $Player
@onready var spawn_point: Marker3D = $SpawnPoint


func _physics_process(_delta: float) -> void:
	# Checado no passo de física porque é nele que o jogador se move.
	if player.global_position.y < fall_limit_y:
		player.teleport(spawn_point.global_transform)
