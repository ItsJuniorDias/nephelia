extends SceneTree
## Ferramenta: tira do pacote Universal Animation Library (Quaternius) só as animações que os
## personagens usam e salva numa AnimationLibrary leve. Rodar de novo se mudar a lista:
##   Godot --headless --path . -s res://tools/extract_bot_animations.gd
##
## Duas fontes: a versão grátis (Standard, dentro do projeto) e a Pro (comprada pelo usuário em
## 2026-09-23, CC0), que fica FORA do projeto em ~/Downloads/nephelia_assets/ e é lida direto do
## glTF. As animações que as duas têm são idênticas (conferido osso a osso); da Pro só entra o que
## a Standard não tem (corrida nas 8 direções). No glTF cru os nomes terminam em "_Loop" (o
## importador do Godot tira esse final); `PRO_ANIMATIONS` diz o nome original.

const SOURCE := "res://assets/animations/quaternius_ual/UAL1_Standard.glb"
const PRO_SOURCE := "Downloads/nephelia_assets/quaternius/Universal Animation Library[Pro]/Unreal-Godot/UAL1.glb"
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
## Da Pro: nome na biblioteca -> [nome no glTF, se repete].
const PRO_ANIMATIONS := {
	"Jog_Fwd_L": ["Jog_Fwd_L_Loop", true],
	"Jog_Left": ["Jog_Left_Loop", true],
	"Jog_Bwd_L": ["Jog_Bwd_L_Loop", true],
	"Jog_Bwd": ["Jog_Bwd_Loop", true],
	"Jog_Bwd_R": ["Jog_Bwd_R_Loop", true],
	"Jog_Right": ["Jog_Right_Loop", true],
	"Jog_Fwd_R": ["Jog_Fwd_R_Loop", true],
}


func _initialize() -> void:
	var source: Node = (load(SOURCE) as PackedScene).instantiate()
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var library := AnimationLibrary.new()
	for anim_name: String in ANIMATIONS:
		var animation: Animation = player.get_animation(anim_name).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if ANIMATIONS[anim_name] else Animation.LOOP_NONE
		library.add_animation(anim_name, animation)
	source.free()

	var pro_path: String = OS.get_environment("HOME").path_join(PRO_SOURCE)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(pro_path, state) != OK:
		push_error("Universal Animation Library Pro não encontrada em %s" % pro_path)
		quit(1)
		return
	var pro: Node = document.generate_scene(state)
	var pro_player: AnimationPlayer = pro.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name: String in PRO_ANIMATIONS:
		var entry: Array = PRO_ANIMATIONS[anim_name]
		var animation: Animation = pro_player.get_animation(entry[0]).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if entry[1] else Animation.LOOP_NONE
		library.add_animation(anim_name, animation)
	pro.free()

	var err: Error = ResourceSaver.save(library, TARGET)
	print("saved %d animations -> %s (%s)" % [library.get_animation_list().size(), TARGET, error_string(err)])
	quit(0 if err == OK else 1)
