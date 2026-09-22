class_name CharacterLook
extends Resource
## Aparência de um personagem: corpo, roupa, cabelo, barba e chapéu (cidade do começo do
## século XX). Quem monta é o `characters/wardrobe.gd`, em código, a partir desta ficha.

enum Body { MALE, FEMALE }
enum Hair { NONE, BUZZED, PARTED, LONG, BUNS }
enum Hat { NONE, BOWLER, TOP_HAT, FLAT_CAP }

@export var body: Body = Body.MALE
## Estampa da roupa (a Peasant tem duas: 0 e 1). A cor do personagem tinge por cima.
@export_range(0, 1) var outfit_variant: int = 0
@export var hair: Hair = Hair.PARTED
## Cor do cabelo, da barba e das sobrancelhas (a textura do pacote é cinza, feita para tingir).
@export var hair_color: Color = Color(0.22, 0.14, 0.09)
@export var beard: bool = false
@export var hat: Hat = Hat.NONE
@export var hat_color: Color = Color(0.12, 0.1, 0.09)
