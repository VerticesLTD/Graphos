extends Node2D
## ==============================================================================
## VERTEX VIEW (The Puppet)
## ==============================================================================
## This script controls the "Body" of a vertex. 
## It is now a "Pure View": it draws its own circle and listens to the Brain.
## ==============================================================================

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var data: Vertex 

## References to our body parts in the Scene Tree.
@onready var label: Label = $Label

## OPTIONAL, add a refrence to circle, and draw it with the scene tree

func _ready() -> void:
	# If we HAVE data, connect to it
	if data:
		data.state_changed.connect(refresh)
	
	# ALWAYS run refresh once so the ghost can set its default look
	refresh()

## This runs every single frame.
func _process(_delta: float) -> void:
	if data:
		# The Puppet follows the Brain's position.
		global_position = data.pos
	
	# If we are the Ghost, the GraphController moves us manually.
	# We queue_redraw to ensure the circle follows the mouse smoothly.
	queue_redraw()

## ------------------------------------------------------------------------------
## VISUAL REFRESH (The Translator)
## ------------------------------------------------------------------------------

func refresh() -> void:
	# Update Position only if we have data.
	if data:
		global_position = data.pos
		label.text = str(data.id)
	else:
		# Ghost specific cleanup
		label.text = ""
		
	# This tells Godot to run the _draw() function again.
	queue_redraw()

## This function handles the actual pixel drawing on screen.
func _draw() -> void:
	# 1. Setup Visual Parameters
	var radius: float = 20.0
	var circle_color: Color
	
	# 2. Decide Color: Use Brain's color if available, otherwise use Ghost white
	if data:
		circle_color = data.color
	else:
		circle_color = Color(1, 1, 1, 0.5) # Faint white for the PlacementPreview
	
	# 3. DRAW THE CIRCLE
	# Vector2.ZERO ensures it is perfectly centered on the node's position.
	draw_circle(Vector2.ZERO, radius, circle_color)
