extends Node


func _ready() -> void:
	_adjust_ui_scale()

func _adjust_ui_scale() -> void:
	if Globals.is_running_on_mobile:
		get_window().content_scale_factor = 2.0
