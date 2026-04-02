## Prim's minimum spanning tree algorithm (start vertex s).
class_name Prim
extends GraphAlgorithm

func get_requirements() -> Dictionary:
	return {
		"weighted": true,
		"directed": false,
		"no_negative_weights": true,
	}

func requires_vertex_keys_display() -> bool:
	return true

func run(_start_vertex: Vertex) -> Array:
	var current_v_processed := 0
	var data_updates: Array = []

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	log_initialize_vertices(COLOR_NOT_DISCOVERED, 1)
	for v: Vertex in imposter_graph.vertices.values():
		v.key = Globals.INF
		v.parent = null
	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"vertices_processed": current_v_processed,
	})

	change_and_log_vertex_key(_start_vertex, 0.0, 2)
	data_updates.append(null)

	var frontier: Array[Vertex] = []
	var in_frontier := {}
	_upsert_frontier(frontier, in_frontier, _start_vertex)
	var settled := {}

	while not frontier.is_empty():
		var u := _pop_min(frontier, in_frontier)
		if u == null:
			break
		if settled.has(u.id):
			continue

		settled[u.id] = true
		change_and_log_vertex_color(u, COLOR_FINISHED, 3)
		current_v_processed += 1
		data_updates.append({&"vertices_processed": current_v_processed})

		for edge in u.get_outgoing_edges():
			var v: Vertex = edge.get_other_vertex(u)
			# State before relax: skip vertices already in the MST (check finished first).
			if settled.has(v.id):
				continue

			var w: float = float(edge.weight)
			if w < v.key:
				change_and_log_edge_color(edge, COLOR_EDGE_PATH, 5)
				data_updates.append(null)

				change_and_log_vertex_key(v, w, 6)
				data_updates.append(null)

				v.parent = u
				_upsert_frontier(frontier, in_frontier, v)

	assert(
		timeline.size() == pseudo_steps.size() and pseudo_steps.size() == data_updates.size(),
		"Prim mismatch: timeline=%d pseudo=%d data=%d" % [timeline.size(), pseudo_steps.size(), data_updates.size()]
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]
	_reset_alg_variables()
	return result


func _upsert_frontier(vertices: Array[Vertex], in_frontier: Dictionary, v: Vertex) -> void:
	if in_frontier.has(v.id):
		return
	vertices.append(v)
	in_frontier[v.id] = true


func _pop_min(vertices: Array[Vertex], in_frontier: Dictionary) -> Vertex:
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
	in_frontier.erase(best.id)
	return best
