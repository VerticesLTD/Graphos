## This class will handle general animations in the graph,
## to avoid graph_controller.gd being too long.
class_name AnimationManager
extends Node

var old_selection: Array[Vertex] = []
var current_selection: Array[Vertex] = []

func update_current_selection(new_selection: Array[Vertex], update_animations=true) -> void:
	old_selection = current_selection.duplicate()
	current_selection = new_selection.duplicate()

	if update_animations:
		update_selected_elements_hover_animations()

func update_selected_elements_hover_animations() -> void:
	# This function highlights all vertices in selection,
	# and all edges whose dst and src are in selection.
	# Also takes care of stopping highlights.

	for v in current_selection:
		v.view.manual_hover_start()
		var edges = v.edges

		while edges:
			if edges.src in current_selection and edges.dst in current_selection:
				var src_idx = current_selection.find(edges.src)
				var dst_idx = current_selection.find(edges.dst)
				var flow_forward = src_idx < dst_idx
				
				edges.view.start_flow_animation(flow_forward)
			edges = edges.next
	
	# Finding elements that no longer need highlighting
	for v in old_selection:
		if v not in current_selection:
			v.view.manual_hover_stop()
			var edges = v.edges

			# This does go over each view twice - Could be optimized
			while edges:
				edges.view.stop_flow_animation()
				edges = edges.next
