extends Node3D
## Fase de teste (greybox): ilha flutuante para experimentar o movimento dos personagens.
## A arte é provisória (formas CSG com cores lisas); os assets de verdade vêm depois.
## A escada (Props/Staircase) tem uma rampa de colisão invisível (StairsRamp):
## o CharacterBody3D não sobe degraus sozinho, e a rampa deixa a subida suave.

## Abaixo desta altura o personagem "caiu da ilha" e volta para o ponto de nascimento.
@export var fall_limit_y: float = -30.0

@onready var spawn_point: Marker3D = $SpawnPoint


func _physics_process(_delta: float) -> void:
	# Vale para o jogador e para os bots. Checado no passo de física, onde eles se movem.
	for node: Node in get_tree().get_nodes_in_group(&"characters"):
		var character := node as Character
		if character.global_position.y < fall_limit_y:
			character.teleport(spawn_point.global_transform)
