## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array[Command]:
	verify_initialization()
	assert(_start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	# Step 1: Initialize the veritces state
	for v in imposter_graph.vertices.values():
		v.color = COLOR_NOT_DISCOVERED # NOT LOGGING so we start AFTER initialization
		v.parent = null
		
				
	change_and_log_vertex_color(_start_vertex, COLOR_VISITING)
	
	# Step 2: Initialize the queue
	var Q = []
	Q.push_back(_start_vertex)

	# We now start looping, so we first show us starting the loop in the pseudo code:
	log_pseudo_step(3,true)

	while Q:
		var u = Q.pop_front()
		log_pseudo_step(4,true)
		
		log_pseudo_step(5,true)
		for edge in u.get_neighbors_edges():
			var v = edge.get_other_vertex(u) # Get the other side of the vertex
			
			log_pseudo_step(6,true)
			if v.color == COLOR_NOT_DISCOVERED:
				# This if's inside is steps 8,9
				for i in range (7,9):
					log_pseudo_step(i,true)

				# 1. Log and change the edge color (The path)
				change_and_log_edge_color(edge, COLOR_EDGE_PATH)

				# 2. Log and change the VERTEX color (The destination)
				change_and_log_vertex_color(v, COLOR_VISITING)

				# 3. Update metadata and queue
				v.parent = u
				Q.push_back(v)
			# End if
			log_pseudo_step(9,true)	

		# End for
		log_pseudo_step(10, true)
			
		change_and_log_vertex_color(u, COLOR_FINISHED)

	# End while
	log_pseudo_step(11,true)

	assert(timeline.size() == pseudo_steps.size(), 
	"After running the algorithm on the imposter graph, the size of pseudo steps" +
	" doesn't match the size of the timeline. This means there is a mistake in the steps setup"
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate()]

	# Resetting for next run
	_reset_alg_variables()

	return result
