extends NavigationRegion3D
## Região de navegação da arena. A navmesh usa fatias de altura de 10 cm (para as rampas
## serem transitáveis com degrau máximo de 20 cm: nosso personagem só sobe rampa, não degrau),
## então o mapa de navegação precisa usar a mesma medida.


func _ready() -> void:
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, navigation_mesh.cell_height)
