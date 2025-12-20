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
	# Set the two points of the line based on the vertices
	points = [data.src.pos, data.dst.pos]
	default_color = data.color
	width = 10.0 # Can use a const also
