class_name DFS
extends GraphAlgorithm

func run(_start_vertex: Vertex) -> Array:
	var current_v_processed = 0

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	for v in imposter_graph.vertices.values():
		v.color = COLOR_NOT_DISCOVERED
		v.parent = null

	var data_updates = []

	# S.push(s) + mark start
	change_and_log_vertex_color(_start_vertex, COLOR_VISITING, 1)
	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"vertices_processed": current_v_processed
	})

	var stack = []
	stack.push_back(_start_vertex)

	while stack:
		var u = stack.pop_back()

		# u = S.pop()
		change_and_log_vertex_color(u, COLOR_VISITING, 3)
		data_updates.append(null)

		for edge in u.get_outgoing_edges():
			var v = edge.get_other_vertex(u)

			if v.color == COLOR_NOT_DISCOVERED:
				# for v in Adj[u] — push neighbor
				change_and_log_edge_color(edge, COLOR_EDGE_PATH, 7)
				data_updates.append(null)

				change_and_log_vertex_color(v, COLOR_VISITING, 7)
				data_updates.append(null)

				v.parent = u
				stack.push_back(v)

		# mark finished
		change_and_log_vertex_color(u, COLOR_FINISHED, 5)
		current_v_processed += 1
		data_updates.append({&"vertices_processed": current_v_processed})

	assert(
		timeline.size() == pseudo_steps.size() and pseudo_steps.size() == data_updates.size(),
		"DFS mismatch: timeline=%d pseudo=%d data=%d" % [timeline.size(), pseudo_steps.size(), data_updates.size()]
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]
	_reset_alg_variables()
	return result
