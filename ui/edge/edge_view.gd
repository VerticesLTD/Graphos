extends Node2D
class_name UIEdgeView
## ==============================================================================
## EDGE VIEW (The Puppet)
## ==============================================================================
## This script controls the "Body" of a connection between two vertices.
## It draws a line between the source and destination provided by the Brain.
## ==============================================================================

## The line's thickness
const WIDTH: float = 4.0

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var edge_data: Edge 

## ------------------------------------------------------------------------------
## LIFE CYCLE
## ------------------------------------------------------------------------------

## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if edge_data:
		# 1. Listen for edge updates (like color changes)
		edge_data.state_changed.connect(refresh)
		
		# 2. Listen for "die" commands and clear
		edge_data.vanished.connect(queue_free)		
		
		# Initial draw
		refresh()		
	else:
		# If there's no edge, delete.
		queue_free()


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
	if not edge_data or not edge_data.src or not edge_data.dst:
		return

	# DRAW THE LINE
	# We pull the positions directly from the Brains of the two connected vertices.
	draw_line(edge_data.src.pos, edge_data.dst.pos, edge_data.color, WIDTH)
