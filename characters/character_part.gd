class_name CharacterPart
extends Resource
## Peça do corpo já pronta para vestir (cabeça, cabelo, barba): a malha e a ligação dela aos
## ossos (`Skin`, pelos nomes dos ossos, então serve em qualquer esqueleto do mesmo padrão).
## Assadas por `tools/bake_characters.gd`; vestidas por `characters/wardrobe.gd`.

@export var mesh: Mesh
@export var skin: Skin
## Caixa da CABEÇA (espaço do esqueleto parado), para assentar o chapéu. Vazia nas peças que
## não são o corpo.
@export var head_box: AABB
