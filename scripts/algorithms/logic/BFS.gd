## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array:
	var current_v_processed = 0
	var data_updates = [
		{
			&"E":imposter_graph.num_edges,
			&"V":imposter_graph.num_vertices,
			&"vertices_processed": current_v_processed
			},null,null
		]

	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	# First 3 steps of the pseudo code have no visible effect:
	for i in range(3):
		log_pseudo_step(i,true)

	# Step 1: Initialize the veritces state
	for v in imposter_graph.vertices.values():
		v.color = COLOR_NOT_DISCOVERED # NOT LOGGING so we start AFTER initialization
		v.parent = null
		
				
	change_and_log_vertex_color(_start_vertex, COLOR_VISITING)
	data_updates.append(null)
	
	# Step 2: Initialize the queue
	var Q = []
	Q.push_back(_start_vertex)

	# We now start looping, so we first show us starting the loop in the pseudo code:
	log_pseudo_step(3,true)
	data_updates.append(null)

	while Q:
		var u = Q.pop_front()
		log_pseudo_step(4,true)
		data_updates.append(null)
		
		log_pseudo_step(5,true)
		data_updates.append(null)
		for edge in u.get_neighbors_edges():
			var v = edge.get_other_vertex(u) # Get the other side of the vertex
			
			log_pseudo_step(6,true)
			data_updates.append(null)
			if v.color == COLOR_NOT_DISCOVERED:
				# This if's inside is steps 8,9
				for i in range (7,9):
					log_pseudo_step(i,true)
					data_updates.append(null)

				# 1. Log and change the edge color (The path)
				change_and_log_edge_color(edge, COLOR_EDGE_PATH)
				data_updates.append(null)

				# 2. Log and change the VERTEX color (The destination)
				change_and_log_vertex_color(v, COLOR_VISITING)
				data_updates.append(null)

				# 3. Update metadata and queue
				v.parent = u
				Q.push_back(v)
			# End if
			log_pseudo_step(9,true)	
			data_updates.append(null)

		# End for
		log_pseudo_step(10, true)
		data_updates.append(null)
			
		change_and_log_vertex_color(u, COLOR_FINISHED)
		current_v_processed += 1
		data_updates.append({&"vertices_processed":current_v_processed})

	# End while
	log_pseudo_step(11,true)
	data_updates.append(null)

	assert(timeline.size() == pseudo_steps.size() and pseudo_steps.size()== data_updates.size(),
	"After running the algorithm on the imposter graph, the size of pseudo steps" +
	" doesn't match the size of the timeline and data steps. This means there is a mistake in the steps setup"
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]

	# Resetting for next run
	_reset_alg_variables()

	return result
