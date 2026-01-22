extends Node

func _ready() -> void:
	if OS.has_feature("editor"):
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://ui/credit_scene/credits.tscn")
