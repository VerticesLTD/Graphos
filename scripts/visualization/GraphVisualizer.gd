## Handles the visual representation of the graph in the scene.
## Acts as the "Receiver" for GraphEvents.
class_name GraphVisualizer
extends Node2D

## Updates the visual color of a specific node.
## @param id    The unique identifier of the node.
## @param color The new color to apply.
func set_node_color(id: int, color: Color) -> void:
	# TODO: Later, we will add code here to find the actual Node sprite and change its color.
	# For now, we print to the Output to prove the connection works.
	print("Visualizer: Set node ", id, " color to ", color)
