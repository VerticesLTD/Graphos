## This class will handle general animations in the graph,
## to avoid graph_controller.gd being too long.
class_name AnimationManager
extends Node

var old_selection: Array[Vertex] = []
var current_selection: Array[Vertex] = []

func update_current_selection(new_selection: Array[Vertex], update_animations=true) -> void:
	old_selection = current_selection.duplicate()
	current_selection = new_selection

	if update_animations:
		update_selected_elements_hover_animations()

func update_selected_elements_hover_animations() -> void:
	pass
