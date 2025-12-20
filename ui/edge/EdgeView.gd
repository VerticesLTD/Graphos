extends Line2D

var data: Edge # The Brain slot

func _ready() -> void:
	if data:
		## REACTION: If the edge data changes (color/pos), redraw the line.
		data.state_changed.connect(refresh)
		
		## SELF-DESTRUCTION: If the edge data is deleted, remove this visual node.
		## 'queue_free' is a built-in Godot function that safely deletes the node.
		data.vanished.connect(queue_free)		
		
		## INITIALIZE: Draw the line immediately when created.
		refresh()		
		
func refresh() -> void:
	# Clear the old points 
	clear_points()
	
	# Create the new points
	add_point(data.src.pos)
	add_point(data.dst.pos)

	# We use 'modulate' as a reactive color filter. 
	# It tints the entire puppet (Sprite + Label) based on the Brain's data,
	# allowing for easy transparency (Alpha) and preserving art details.	
	self.modulate = data.color
