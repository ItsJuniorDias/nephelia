class_name PowerResult
extends RefCounted
## Resultado do uso de um poder, decidido pelo MatchReferee (o juiz da partida).
##
## Serve para os efeitos (raio, sopro, sons) saberem o que desenhar, como o ShotResult faz
## com os tiros.

enum Kind { SPARK, GUST }

var kind: Kind = Kind.SPARK
var caster: Character
## De onde o poder saiu (olho de quem usou).
var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
## Onde o raio terminou (só a Faísca; a Rajada termina no alcance dela).
var end_point: Vector3 = Vector3.ZERO
## Quem foi atingido.
var victims: Array[Character] = []
var damage: float = 0.0
