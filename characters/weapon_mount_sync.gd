class_name WeaponMountSync
extends SkeletonModifier3D
## Atualiza o WeaponMount DENTRO da etapa do esqueleto: depois das animações e do tronco
## destorcido (TorsoFacingModifier) e antes das mãos irem até a arma (WeaponGripModifier).
## Atualizado no `_process`, o suporte lia o peito de um quadro antes: correndo, a mão esquerda
## ficava até 10 cm longe da telha.

var mount: WeaponMount


func _process_modification_with_delta(delta: float) -> void:
	if mount != null:
		mount.sync(delta)
