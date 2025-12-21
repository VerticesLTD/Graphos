extends Node2D
## ==============================================================================
## EDGE VIEW (The Puppet)
## ==============================================================================
## This script controls the "Body" of a connection between two vertices.
## It draws a line between the source and destination provided by the Brain.
## ==============================================================================

## The line's thickness
const WIDTH: float = 4.0

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var data: Edge 

## ------------------------------------------------------------------------------
## LIFE CYCLE
## ------------------------------------------------------------------------------

## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if data:
		# 1. Listen for data updates (like color changes)
		data.state_changed.connect(refresh)
		
		# 2. Listen for "die" commands and clear
		data.vanished.connect(queue_free)		
		
		# Initial draw
		refresh()		
	else:
		# If there's no data, delete.
		queue_free()

## This runs every single frame.
func _process(_delta: float) -> void:
	# Constant update so the line follows moving circles smoothly.
	# We use queue_redraw here because the line's shape is always changing.
	queue_redraw()

## ------------------------------------------------------------------------------
## VISUAL REFRESH
## ------------------------------------------------------------------------------

## Called when the brain's state changes.
func refresh() -> void:
	# Trigger redraw to catch visual changes like color.
	queue_redraw()

## This function handles the actual line drawing on screen.
func _draw() -> void:
	# Stop if the brain or its endpoints are missing.
	if not data or not data.src or not data.dst:
		return

	# DRAW THE LINE
	# We pull the positions directly from the Brains of the two connected vertices.
	draw_line(data.src.pos, data.dst.pos, data.color, WIDTH)
