## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

func get_requirements() -> Dictionary:
	return {"weighted": false}

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array:
	var current_v_processed = 0
	var data_updates = []

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	# Silent pre-run state setup (visible in graph, not part of timeline playback).
	for v in imposter_graph.vertices.values():
		set_vertex_color_silent(v, COLOR_NOT_DISCOVERED)
		v.parent = null

	change_and_log_vertex_color(_start_vertex, COLOR_VISITING, 4)
	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"vertices_processed": current_v_processed
	})

	var queue = []
	queue.push_back(_start_vertex)

	while queue:
		var u = queue.pop_front()
		for edge in u.get_outgoing_edges():
			var v = edge.get_other_vertex(u)
			if v.color == COLOR_NOT_DISCOVERED:
				change_and_log_edge_color(edge, COLOR_EDGE_PATH, 9)
				data_updates.append(null)

				change_and_log_vertex_color(v, COLOR_VISITING, 10)
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
