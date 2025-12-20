## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

## Initialize the graph.
## @param gtaph    The graph to run the algorithm on.
func _init(g: UndirectedGraph):
	# This passes graph up to GraphAlgorithm's _init
	super(g) 

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array[Action]:
	# Step 1: Initialize the veritces state
	for v in graph.vertices.values():
		change_and_log_vertex_color(v, COLOR_NOT_DISCOVERED)
		v.parent = null
		
	change_and_log_vertex_color(_start_vertex, COLOR_VISITING)
	# OPTIONAL - save the state as a critical point, so we could skip forward to it!
	
	# Step 2: Initialize the queue
	var Q = []
	Q.push_back(_start_vertex)

	# Step 3: Start searching
	while Q:
		var u = Q.pop_front()
		
		# Step 4: Process vetex
		for edge in u.get_neighbors_edges():
			var v = edge.get_other_vertex(u) # Get the other side of the vertex
			
			if v.color == COLOR_NOT_DISCOVERED:
				# 1. Log and change the edge color (The path)
				change_and_log_edge_color(edge, COLOR_VISITING)

				# 2. Log and change the VERTEX color (The destination)
				change_and_log_vertex_color(v, COLOR_VISITING)

				# 3. Update metadata and queue
				v.parent = u
				Q.push_back(v)
	return timeline
