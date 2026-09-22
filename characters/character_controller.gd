class_name CharacterController
extends Node
## Base dos controladores: decide o comando do personagem a cada passo de física.
##
## Tipos: HumanController (toque, teclado/mouse, controle), BotController (IA) e, no futuro,
## um controlador de rede. O personagem procura o controlador entre os seus filhos.

var character: Character
## Em que cone (a partir do olhar) este controlador procura trilhos para engatar. O humano
## precisa olhar para o trilho; o bot "sabe onde eles estão" e usa 360°.
var rail_hook_cone: float = deg_to_rad(30.0)
## Comando reaproveitado a cada passo (evita criar um objeto novo 60 vezes por segundo).
var command: CharacterCommand = CharacterCommand.new()


## Chamado pelo personagem quando ele está pronto (depois dos @onready dele).
func setup(for_character: Character) -> void:
	character = for_character


## Preenche e devolve o comando deste passo. Cada tipo de controlador sobrescreve.
func get_command(_delta: float) -> CharacterCommand:
	command.reset()
	command.yaw = character.yaw
	command.pitch = character.pitch
	return command
