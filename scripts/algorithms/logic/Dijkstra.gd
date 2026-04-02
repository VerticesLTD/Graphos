## Class to run Dijkstra's shortest path algorithm and log it.
class_name Dijkstra
extends GraphAlgorithm

func get_requirements() -> Dictionary:
	return {
		"weighted": true,
		"no_negative_weights": true
	}

func requires_vertex_keys_display() -> bool:
	return true

## run function for the algorithm
## @param _start_vertex The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array:
	var current_v_processed := 0
	var data_updates := []

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	# Step 1: initialize all vertices as undiscovered.
	log_initialize_vertices(COLOR_NOT_DISCOVERED, 1)
	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"vertices_processed": current_v_processed
	})

	# Source starts with key=0.
	change_and_log_vertex_key(_start_vertex, 0.0, 3)
	data_updates.append(null)

	var frontier: Array[Vertex] = [_start_vertex]
	var settled := {}

	while not frontier.is_empty():
		var u := _pop_min_vertex(frontier)
		if u == null:
			break
		if settled.has(u.id):
			continue

		settled[u.id] = true
		change_and_log_vertex_color(u, COLOR_FINISHED, 7)
		current_v_processed += 1
		data_updates.append({&"vertices_processed": current_v_processed})

		for edge in u.get_outgoing_edges():
			var v: Vertex = edge.get_other_vertex(u)
			if settled.has(v.id):
				continue

			var candidate := u.key + float(edge.weight)
			if candidate < v.key:
				change_and_log_edge_color(edge, COLOR_EDGE_PATH, 10)
				data_updates.append(null)

				change_and_log_vertex_key(v, candidate, 11)
				data_updates.append(null)

				v.parent = u
				frontier.append(v)

	assert(
		timeline.size() == pseudo_steps.size() and pseudo_steps.size() == data_updates.size(),
		"Dijkstra mismatch: timeline=%d pseudo=%d data=%d" % [timeline.size(), pseudo_steps.size(), data_updates.size()]
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]
	_reset_alg_variables()
	return result

func _pop_min_vertex(vertices: Array[Vertex]) -> Vertex:
	if vertices.is_empty():
		return null

	var best_index := 0
	var best_key := vertices[0].key

	for i in range(1, vertices.size()):
		var k := vertices[i].key
		if k < best_key:
			best_key = k
			best_index = i

	var best: Vertex = vertices[best_index]
	vertices.remove_at(best_index)
	return best
