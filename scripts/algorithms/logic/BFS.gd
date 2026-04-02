## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

func get_requirements() -> Dictionary:
	return {"warn_if_weighted": true}

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array:
	var current_v_processed = 0
	var data_updates = []

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	# Step 1: initialize all vertices as undiscovered (one press, fully undoable).
	log_initialize_vertices(COLOR_NOT_DISCOVERED, 1)
	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"vertices_processed": current_v_processed
	})

	change_and_log_vertex_color(_start_vertex, COLOR_VISITING, 4)
	data_updates.append(null)

	var queue = []
	queue.push_back(_start_vertex)

	while queue:
		var u = queue.pop_front()
		for edge in u.get_outgoing_edges():
			var v = edge.get_other_vertex(u)
			if v.color == COLOR_NOT_DISCOVERED:
				discover_vertex_via_edge_and_log(edge, v, COLOR_EDGE_PATH, COLOR_VISITING, 10)
				data_updates.append(null)

				v.parent = u
				queue.push_back(v)

		change_and_log_vertex_color(u, COLOR_FINISHED, 11)
		current_v_processed += 1
		data_updates.append({&"vertices_processed": current_v_processed})

	assert(
		timeline.size() == pseudo_steps.size() and pseudo_steps.size() == data_updates.size(),
		"BFS mismatch: timeline=%d pseudo=%d data=%d" % [timeline.size(), pseudo_steps.size(), data_updates.size()]
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]

	# Resetting for next run
	_reset_alg_variables()

	return result
