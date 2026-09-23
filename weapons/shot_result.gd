class_name ShotResult
extends RefCounted
## Resultado de um tiro, decidido pelo MatchReferee (o juiz da partida).

var shooter: Character
var weapon: Weapon
## De onde o tiro saiu (olho do atirador).
var origin: Vector3 = Vector3.ZERO
## Direção final, já com a mira assistida e a imprecisão aplicadas.
var direction: Vector3 = Vector3.FORWARD
## Onde o tiro terminou: o ponto atingido ou o alcance máximo.
var end_point: Vector3 = Vector3.ZERO
## Onde terminaram os outros chumbos (espingarda); vazio nas armas de uma bala só.
var pellet_points: PackedVector3Array = PackedVector3Array()
## Para cada raio (o 1º termina no `end_point`, os outros nos `pellet_points`): a normal da
## superfície atingida (ZERO = não acertou nada) e se o que ele acertou foi um personagem.
var ray_normals: PackedVector3Array = PackedVector3Array()
var ray_hit_character: Array[bool] = []
## Acertou alguma coisa (cenário ou personagem).
var hit: bool = false
var hit_normal: Vector3 = Vector3.UP
## Personagem atingido (null se acertou cenário ou nada).
var victim: Character
var damage: float = 0.0
## A mira assistida puxou este tiro para um alvo.
var assisted: bool = false
