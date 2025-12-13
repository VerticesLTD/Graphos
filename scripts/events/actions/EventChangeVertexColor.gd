## Represents a specific graph modification event where a vertex changes its visual color.
## This class captures the state required to apply and revert a color change operation.
class_name EventChangeVertexColor
extends GraphEvent

## The unique identifier of the target vertex.
var node_id: int

## The target color to apply during forward execution.
var new_color: Color

## The original color stored for undo/revert operations.
var old_color: Color


## Initializes the color change event with the necessary state snapshots.
## @param id              The ID of the vertex being modified.
## @param target_color    The new color to apply.
## @param previous_color  The current color (saved for undo).
func _init(id: int, target_color: Color, previous_color: Color):
	node_id = id
	new_color = target_color
	old_color = previous_color

## Executes the forward action.
## Updates the visualizer to display the new color for the specified node.
## @param visualizer The main graph visualizer instance (must implement set_node_color).
func execute(visualizer: GraphVisualizer) -> void:
	visualizer.set_node_color(node_id, new_color)

## Reverts the action.
## Restores the visualizer to the original color of the specified node.
## @param visualizer The main graph visualizer instance.
func undo(visualizer: GraphVisualizer) -> void:
	visualizer.set_node_color(node_id, old_color)
