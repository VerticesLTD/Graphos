class_name UISelectionBounds
extends Node2D

@onready var controller: GraphController = get_parent()

func _process(_delta: float) -> void:
	# Always ask for a redraw so it stays synced with vertex movement
	queue_redraw()

func _draw() -> void:
	if controller.selection_buffer.size() > 1:
		var rect = controller.selection_bounds
		var color = Globals.SELECTION_BORDER_COLOR
		var dash_length = 5.0
		
		# Calculate the four corners
		var tl = rect.position
		var tr = Vector2(rect.end.x, rect.position.y)
		var bl = Vector2(rect.position.x, rect.end.y)
		var br = rect.end
		
		# Draw the 4 sides
		draw_dashed_line(tl, tr, color, 1.0, dash_length) # Top
		draw_dashed_line(tr, br, color, 1.0, dash_length) # Right
		draw_dashed_line(br, bl, color, 1.0, dash_length) # Bottom
		draw_dashed_line(bl, tl, color, 1.0, dash_length) # Left
