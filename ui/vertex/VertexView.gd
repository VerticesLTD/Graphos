extends Node2D

## ==============================================================================
## VERTEX VIEW (The Puppet)
## ==============================================================================
## This script controls the "Body" of a vertex. 
## It doesn't do any math; it just sits there, listens for the "Brain" (Vertex.gd)
## to shout, and moves the pixels to match.
## ==============================================================================

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var data: Vertex 

## State variable to track if the user is currently moving us.
var is_dragging: bool = false

## References to our body parts in the Scene Tree.
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	# If for some reason we were born without a brain, stop immediately.
	if not data: 
		return
		
	# HANDSHAKE: We subscribe to the Brain's signal.
	# Whenever a variable in Vertex.gd changes, it shouts 'state_changed'.
	# We hear that shout and run our 'refresh' function.
	data.state_changed.connect(refresh)
	
	# Do a first-time setup so we appear at the right spot immediately.
	refresh()

## ------------------------------------------------------------------------------
## INPUT & MOVEMENT LOGIC
## ------------------------------------------------------------------------------

## This runs whenever you move the mouse or click a button.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# If we clicked DOWN over the circle, start dragging.
			# If we released the button, stop dragging.
			if event.pressed and is_mouse_over():
				is_dragging = true
			else:
				is_dragging = false

## This runs every single frame (the heart-beat of the game).
func _process(_delta: float) -> void:
	if is_dragging:
		# IMPORTANT: We don't move the Sprite directly!
		# We update the BRAIN's position. The Brain then shouts 'state_changed',
		# which triggers 'refresh()', which finally moves these pixels.
		# This ensures the data and the visuals are ALWAYS in sync.
		data.pos = get_global_mouse_position()

## A helper function to see if the mouse is touching the circle.
func is_mouse_over() -> bool:
	# We calculate the distance from the mouse to our center.
	# If it's less than 20 pixels, the mouse is "inside" the vertex.
	# 20 is just an example.
	return get_local_mouse_position().length() < 20.0

## ------------------------------------------------------------------------------
## VISUAL REFRESH (The Translator)
## ------------------------------------------------------------------------------

## This is the function that actually touches the pixels.
func refresh() -> void:
	# 1. Update Position: Move the whole Puppet to match the Brain's math.
	global_position = data.pos
	
	# VISUAL TINT: We use 'modulate' because it acts like a color filter.
	# It lets us change the vertex to any color (like Red for Dijkstra or Green for BFS)
	# while keeping the original shadows and transparency intact.	sprite.modulate = data.color	
	sprite.modulate = data.color
	
	# 3. Update Text: Show the ID (or distance/weight) on the label.
	label.text = str(data.id)
