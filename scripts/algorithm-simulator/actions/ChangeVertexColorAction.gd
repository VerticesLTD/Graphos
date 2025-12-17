## Represents an action where a vertex changes its visual color.
## This class captures the state required to apply and revert a vertex color change action.
class_name ChangeVertexColorAction
extends Action

## The the target vertex of the action.
var target_vertex: Vertex

## The target color to apply during forward execution.
var new_color: Color

## The original color stored for undo operations.
var old_color: Color


## Initializes the color change event with the necessary state snapshots.
## @param target_vertex     The vertex being modified.
## @param target_color    The new color to apply.
## @param previous_color  The current color (saved for undo).
func _init(vertex: Vertex, target_color: Color, previous_color: Color):
	target_vertex = vertex
	new_color = target_color
	old_color = previous_color

## Executes the forward action.
## Changes the vertex's color to new_color 
func execute() -> void:
	target_vertex.color = new_color
	# target_vertex.queue_redraw() do i need it here? has to be in vertex class, help.

## Reverts the action.
## Restores the original color of the vertex.
func undo() -> void:
	target_vertex.color = old_color
	# target_vertex.queue_redraw() do i need it here? has to be in vertex class, help.
