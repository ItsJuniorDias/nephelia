class_name CharacterCommand
extends RefCounted
## O que um personagem quer fazer neste passo de física.
##
## Humano, bot e (no futuro) jogador pela rede preenchem o mesmo comando, e o personagem só
## obedece. O olhar vai em ângulos ABSOLUTOS: pela rede, um valor absoluto perdido não
## acumula erro, como aconteceria com "gire 3°" perdido.

## Direção de movimento, de -1 a 1 (x = direita, y = trás), igual a Input.get_vector().
var move: Vector2 = Vector2.ZERO
## Para onde o corpo aponta (radianos, em volta do eixo Y).
var yaw: float = 0.0
## Inclinação da cabeça (radianos, positivo = para cima).
var pitch: float = 0.0
## Pular está apertado (ou foi tocado) neste passo.
var jump: bool = false
## Atirar está apertado neste passo.
var fire: bool = false


## Limpa os botões e o movimento (o olhar é sempre preenchido pelo controlador).
func reset() -> void:
	move = Vector2.ZERO
	jump = false
	fire = false
