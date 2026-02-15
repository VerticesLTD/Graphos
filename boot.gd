extends Node

const CREDITS = preload("uid://c1t7e0pf81xoe")
const MAIN = preload("uid://yxcr5kwlindq")

func _ready() -> void:
	if OS.has_feature("editor"):
		get_tree().change_scene_to_packed.call_deferred(MAIN)
	else:
		get_tree().change_scene_to_packed.call_deferred(CREDITS)
