extends Node2D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey:
		get_tree().change_scene_to_file("res://main.tscn")
