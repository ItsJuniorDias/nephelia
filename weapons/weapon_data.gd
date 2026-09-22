class_name WeaponData
extends Resource
## Ficha de uma arma: quanto ela machuca, o ritmo, o tambor e a malha que aparece na mão.
##
## A arma do personagem (`weapons/weapon.gd`) é sempre o mesmo nó: pegar um item de arma só
## troca a ficha dele. As fichas do jogo estão em `weapons/weapon_catalog.gd`.

## Nome curto usado no código e nos itens (ex.: "revolver", "repeater", "shotgun").
@export var id: StringName = &"revolver"
## Nome mostrado no HUD.
@export var weapon_name: String = "Revolver"
@export_range(1.0, 200.0, 1.0) var damage: float = 34.0
## Tempo mínimo entre tiros. Segurar o gatilho continua atirando nesse ritmo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var fire_interval: float = 0.35
@export_range(1, 100, 1) var magazine_size: int = 6
@export_range(0.1, 5.0, 0.05, "suffix:s") var reload_time: float = 1.6
@export_range(5.0, 500.0, 1.0, "suffix:m") var max_range: float = 80.0
## Imprecisão: cada bala sai num cone aleatório deste tamanho.
@export_range(0.0, 20.0, 0.1, "suffix:°") var spread_degrees: float = 0.6
## Balas por tiro (espingarda atira vários chumbos de uma vez).
@export_range(1, 20, 1) var pellets: int = 1
## Munição guardada, fora do tambor. -1 = infinita (a arma que o personagem sempre tem).
@export var reserve_ammo: int = -1

@export_group("Som")
@export var shot_sound: AudioStream
@export var reload_sound: AudioStream

@export_group("Sensação")
## Força do coice (1 = revólver).
@export_range(0.2, 3.0, 0.05) var recoil: float = 1.0
## Tom e volume do tiro (armas maiores soam mais graves e mais alto).
@export_range(0.3, 2.0, 0.01) var shot_pitch: float = 1.0
@export_range(-12.0, 12.0, 0.5, "suffix:dB") var shot_volume_db: float = 0.0
## Tamanho do clarão do cano (1 = revólver).
@export_range(0.3, 3.0, 0.05) var flash_scale: float = 1.0
## Movimento da recarga das armas longas (as animações são de pistola): inclina o cano
## (graus, - = para baixo), gira de lado (graus) e abaixa (metros), no meio da recarga.
@export var reload_motion: Vector3 = Vector3.ZERO

@export_group("Aparência")
@export var mesh: Mesh
## Lugar da arma na mão direita. Atenção: no arquivo de cena a matriz é escrita por LINHAS e
## em código por COLUNAS (uma é a transposta da outra).
@export var in_hand: Transform3D = Transform3D.IDENTITY
## Ponta do cano, no espaço da arma (de onde sai o rastro do tiro).
@export var barrel_tip: Vector3 = Vector3.ZERO
## Onde a MÃO DIREITA segura esta arma (pose do osso do pulso, no espaço da arma). Só as armas
## longas usam: o revólver fica na mão como a animação manda (`in_hand`).
@export var right_grip: Transform3D = Transform3D.IDENTITY
## Onde a MÃO ESQUERDA segura esta arma (pose do osso do pulso, no espaço da arma). Só as
## armas longas usam.
@export var fore_grip: Transform3D = Transform3D.IDENTITY
## Lugar da arma em relação ao PEITO (espaço do modelo, na pose de descanso). Com a identidade
## aqui a arma fica na mão direita, seguindo a animação; com um valor, ela é apoiada no peito e
## as duas mãos vão até ela por IK, que é como se segura um rifle.
@export var chest_mount: Transform3D = Transform3D.IDENTITY


## Arma comprida: apoiada no peito, com as duas mãos levadas até ela.
func is_two_handed() -> bool:
	return not chest_mount.is_equal_approx(Transform3D.IDENTITY)


## Munição infinita: esta arma nunca acaba (o personagem volta para ela quando as outras acabam).
func is_endless() -> bool:
	return reserve_ammo < 0
