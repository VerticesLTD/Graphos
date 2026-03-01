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

	# Start animations for the CURRENT selection
	for v in current_selection:
		# Tell the Brain to request an animation from its View
		v.animation_requested.emit("hover_start")
		
		var e = v.edges
		while e:
			# If the destination is ALSO selected, light up the edge between them
			if e.dst in current_selection:
				e.animation_requested.emit("hover_start")
			e = e.next
			
	# Stop animations for elements that are NO LONGER selected
	for v in old_selection:
		# Safety Check: Did the user delete this vertex while it was selected?
		if not is_instance_valid(v):
			continue

		# If it survived, but is no longer in the active selection, turn it off
		if v not in current_selection:
			v.animation_requested.emit("hover_stop")
			
			var e = v.edges
			while e:
				# Turn off the connected edges as well
				if is_instance_valid(e):
					e.animation_requested.emit("hover_stop")
				e = e.next
