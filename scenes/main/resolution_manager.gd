extends Node


func _ready() -> void:
	_adjust_ui_scale()

func _is_mobile_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")

func _adjust_ui_scale() -> void:
	if _is_mobile_web():
		get_window().content_scale_factor = 2.0
