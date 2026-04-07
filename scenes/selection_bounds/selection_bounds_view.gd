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
	# Keep dashed border readable at any zoom (constant-ish screen thickness).
	var dash_gap = 6.0 * ui_scale
	var line_width = clampf(1.5 * ui_scale, 0.8, 3.5)
	
	# Corners
	var tl = rect.position
	var _tr = Vector2(rect.end.x, rect.position.y) # tr alone is defined in Object class
	var bl = Vector2(rect.position.x, rect.end.y)
	var br = rect.end
	
	# Draw Dashed Border
	draw_dashed_line(tl, _tr, color, line_width, dash_gap)
	draw_dashed_line(_tr, br, color, line_width, dash_gap)
	draw_dashed_line(br, bl, color, line_width, dash_gap)
	draw_dashed_line(bl, tl, color, line_width, dash_gap)
	
	# Handle size is capped so handles stay proportional to vertices when zoomed out.
	# A pure "8 * ui_scale" would make them dwarf the nodes at low zoom levels.
	var handle_size := _handle_world_size(ui_scale)

	# Corner handles — always drawn; signal diagonal (two-axis) resize.
	for pos in [tl, _tr, bl, br]:
		_draw_handle(pos, handle_size, ui_scale)

	# Edge-midpoint handles — only drawn when ≥ 2 vertices are selected,
	# because single-vertex resize is undefined and we don't want phantom affordances.
	# Slightly smaller than corners to visually hint that they scale one axis only.
	if controller.selection_buffer.size() >= 2:
		var mid_top    := Vector2((tl.x + _tr.x) * 0.5, tl.y)
		var mid_bottom := Vector2((bl.x + br.x) * 0.5, br.y)
		var mid_left   := Vector2(tl.x, (tl.y + bl.y) * 0.5)
		var mid_right  := Vector2(_tr.x, (_tr.y + br.y) * 0.5)
		var edge_size  := handle_size * 0.72
		for pos in [mid_top, mid_bottom, mid_left, mid_right]:
			_draw_handle(pos, edge_size, ui_scale)

func _handle_world_size(ui_scale: float) -> float:
	var target_screen_px := 8.0
	var uncapped := target_screen_px * ui_scale
	var max_world: float = Globals.VERTEX_RADIUS * 0.85
	return clampf(minf(uncapped, max_world), 1.2, max_world)

func _draw_handle(pos: Vector2, size: float, outline_scale: float) -> void:
	var handle_rect = Rect2(pos - Vector2(size/2, size/2), Vector2(size, size))
	draw_rect(handle_rect, Color.WHITE, true) # Fill
	draw_rect(handle_rect, Globals.SELECTION_BORDER_COLOR, false, clampf(outline_scale, 0.5, 2.0))

func _get_camera_zoom_factor() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 1.0
	return maxf(camera.zoom.x, 0.001)
