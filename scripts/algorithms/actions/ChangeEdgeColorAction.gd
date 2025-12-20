## Represents an action where an edge changes its visual color.
## This class captures the state required to apply and revert an edge color change action.
class_name ChangeEdgeColorAction
extends Action

## The the target edge of the action.
var target_edge: Edge

## The target color to apply during forward execution.
var new_color: Color

## The original color stored for undo operations.
var old_color: Color


## Initializes the color change event with the necessary state snapshots.
## @param target_edge     The edge being modified.
## @param target_color    The new color to apply.
## @param previous_color  The current color (saved for undo).
func _init(edge: Edge, target_color: Color, previous_color: Color):
	target_edge = edge
	new_color = target_color
	old_color = previous_color

## Executes the forward action.
## Changes the edge's color to new_color 
func execute() -> void:
	target_edge.color = new_color

## Reverts the action.
## Restores the original color of the edge.
func undo() -> void:
	target_edge.color = old_color
