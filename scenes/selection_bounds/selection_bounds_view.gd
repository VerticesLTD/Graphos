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
	var dash_gap = 6.0
	
	# Corners
	var tl = rect.position
	var tr = Vector2(rect.end.x, rect.position.y)
	var bl = Vector2(rect.position.x, rect.end.y)
	var br = rect.end
	
	# Draw Dashed Border
	draw_dashed_line(tl, tr, color, 1.5, dash_gap)
	draw_dashed_line(tr, br, color, 1.5, dash_gap)
	draw_dashed_line(br, bl, color, 1.5, dash_gap)
	draw_dashed_line(bl, tl, color, 1.5, dash_gap)
	
	# Draw Excalidraw-style Handles
	for pos in [tl, tr, bl, br]:
		_draw_handle(pos)

func _draw_handle(pos: Vector2) -> void:
	var size = 8.0
	var handle_rect = Rect2(pos - Vector2(size/2, size/2), Vector2(size, size))
	draw_rect(handle_rect, Color.WHITE, true) # Fill
	draw_rect(handle_rect, Globals.SELECTION_BORDER_COLOR, false, 1.0) # Outline
