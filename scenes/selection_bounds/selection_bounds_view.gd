class_name UISelectionBounds
extends Node2D

@onready var controller: GraphController = get_parent()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if controller.selection_buffer.is_empty():
		return
		
	var rect = controller.selection_bounds
	var color = Globals.SELECTION_BORDER_COLOR
	var zoom_factor = _get_camera_zoom_factor()
	var ui_scale = 1.0 / zoom_factor
	var dash_gap = 6.0 * ui_scale
	var line_width = 1.5 * ui_scale
	
	# Corners
	var tl = rect.position
	var _tr = Vector2(rect.end.x, rect.position.y) # tr alone is define in Object class
	var bl = Vector2(rect.position.x, rect.end.y)
	var br = rect.end
	
	# Draw Dashed Border
	draw_dashed_line(tl, _tr, color, line_width, dash_gap)
	draw_dashed_line(_tr, br, color, line_width, dash_gap)
	draw_dashed_line(br, bl, color, line_width, dash_gap)
	draw_dashed_line(bl, tl, color, line_width, dash_gap)
	
	# Draw Excalidraw-style Handles
	for pos in [tl, _tr, bl, br]:
		_draw_handle(pos, ui_scale)

func _draw_handle(pos: Vector2, ui_scale: float) -> void:
	var size = 8.0 * ui_scale
	var handle_rect = Rect2(pos - Vector2(size/2, size/2), Vector2(size, size))
	draw_rect(handle_rect, Color.WHITE, true) # Fill
	draw_rect(handle_rect, Globals.SELECTION_BORDER_COLOR, false, ui_scale) # Outline

func _get_camera_zoom_factor() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 1.0
	return maxf(camera.zoom.x, 0.001)
