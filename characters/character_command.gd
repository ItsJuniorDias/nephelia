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
## Recarregar foi pedido neste passo.
var reload: bool = false
## Pede ajuda de mira (toque e controle; no mouse fica desligada).
var aim_assist: bool = false
## Engatar/soltar do trilho aéreo está apertado neste passo.
var use_rail: bool = false
## Número do comando na rede (sobe um por passo de física; -1 = fora do multiplayer). O
## anfitrião confirma até qual já processou, e o sorteio da imprecisão do tiro usa este número
## (o cliente desenha o mesmo tiro que o anfitrião decide).
var tick: int = -1
## Multiplayer: momento (passo do anfitrião) em que o cliente estava vendo os outros quando mandou
## este comando. O anfitrião volta os alvos para lá ao decidir o tiro (compensação do atraso).
var view_tick: float = 0.0


## Limpa os botões e o movimento (o olhar é sempre preenchido pelo controlador).
func reset() -> void:
	move = Vector2.ZERO
	jump = false
	fire = false
	reload = false
	aim_assist = false
	use_rail = false


## Copia tudo de `other` (a rede guarda cópias; o controlador reaproveita o mesmo objeto).
func copy_from(other: CharacterCommand) -> void:
	move = other.move
	yaw = other.yaw
	pitch = other.pitch
	jump = other.jump
	fire = other.fire
	reload = other.reload
	aim_assist = other.aim_assist
	use_rail = other.use_rail
	tick = other.tick
	view_tick = other.view_tick


func duplicate_command() -> CharacterCommand:
	var copy := CharacterCommand.new()
	copy.copy_from(self)
	return copy
