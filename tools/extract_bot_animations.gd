extends SceneTree
## Ferramenta: tira do pacote Universal Animation Library (Quaternius) só as animações que os
## personagens usam e salva numa AnimationLibrary leve. Rodar de novo se mudar a lista:
##   Godot --headless --path . -s res://tools/extract_bot_animations.gd

const SOURCE := "res://assets/animations/quaternius_ual/UAL1_Standard.glb"
const TARGET := "res://assets/animations/quaternius_ual/character_animations.res"
## Nome da animação -> se repete (loop).
const ANIMATIONS := {
	"Idle": true,
	"Walk": true,
	"Jog_Fwd": true,
	"Pistol_Idle": true,
	"Pistol_Aim_Neutral": true,
	"Pistol_Aim_Up": true,
	"Pistol_Aim_Down": true,
	"Pistol_Shoot": false,
	"Pistol_Reload": false,
	"Hit_Chest": false,
	"Death01": false,
	"Jump": true,
}


func _initialize() -> void:
	var source: Node = (load(SOURCE) as PackedScene).instantiate()
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var library := AnimationLibrary.new()
	for anim_name: String in ANIMATIONS:
		var animation: Animation = player.get_animation(anim_name).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if ANIMATIONS[anim_name] else Animation.LOOP_NONE
		library.add_animation(anim_name, animation)
	var err: Error = ResourceSaver.save(library, TARGET)
	print("saved %d animations -> %s (%s)" % [ANIMATIONS.size(), TARGET, error_string(err)])
	source.free()
	quit(0 if err == OK else 1)
