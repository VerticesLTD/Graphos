extends Node2D
class_name UIVertexView
## ==============================================================================
## VERTEX VIEW (The Puppet)
## ==============================================================================
## This script controls the "Body" of a vertex. 
## It is now a "Pure View": it draws its own circle and listens to the Brain.
## ==============================================================================

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var vertex_data: Vertex 

## References to our body parts in the Scene Tree.
@onready var label: Label = $Label

## ------------------------------------------------------------------------------
## LIFE CYCLE
## ------------------------------------------------------------------------------

## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if vertex_data:
		# 1. Listen for vertex updates (like if the nodes move)
		vertex_data.state_changed.connect(refresh)

		# 2. Listen for "die" commands and clear
		vertex_data.vanished.connect(_on_vanished)
		
		# Initial draw
		refresh()
	else:
		# If there's no data, delete.
		queue_free()

## This runs every single frame.
func _process(_delta: float) -> void:
	# Always follow the brain, good for dragging.
	global_position = vertex_data.pos

## ------------------------------------------------------------------------------
## VISUAL REFRESH 
## ------------------------------------------------------------------------------

## Called when something had changed.
func refresh() -> void:
	# Only repaint and relabel if the color/radius/label changed.
	label.text = str(vertex_data.id)
	self.z_index = vertex_data.z_idx
	queue_redraw()

## This function handles the actual pixel drawing on screen.
func _draw() -> void:
	# If the brain isn't plugged in yet, stop everything.
	if not vertex_data:
		return
		
	# 1. Setup Color: Use Brain's color (Data is guaranteed by _ready)
	var circle_color: Color = vertex_data.color
	
	# 2. DRAW THE CIRCLE
	# Vector2.ZERO ensures it draws on the node'ss origin.
	draw_circle(Vector2.ZERO, Globals.VERTEX_RADIUS, circle_color)

# Called when we delete the vertex
func _on_vanished(_v: Vertex) -> void:
	queue_free()
