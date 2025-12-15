## Class to run the BFS algorithm on a graph and log it.
class_name BFS
extends GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color.WHITE
const COLOR_VISITING = Color.YELLOW
const COLOR_FINISHED = Color.GREEN

## Initialize the graph.
## @param gtaph    The graph to run the algorithm on.
func _init(graph: UndirectedGraph):
	# This passes gtaph up to GraphAlgorithm's _init
	# Fixed: using the parameter name 'gtaph'
	super(graph) 

## run function for the algorithm
## @param _start_vertex    The vertex the algorithm starts from
func run(_start_vertex: Vertex) -> Array[Action]:
	# Step 1: Initialize the veritces state
	for vertex in graph.vertices.values():
		vertex.color = COLOR_NOT_DISCOVERED
		# Oprional - add this color change as an action
		# timeline.append(ChangeEdgeColorAction(vertex, COLOR_NOT_DISCOVERED, vertex.color))
		vertex.parent = null
		
	# initialize the start vertex color
	var start_color_before_change = _start_vertex.color
	# log the color change
	timeline.append(ChangeVertexColorAction.new(_start_vertex, COLOR_VISITING, start_color_before_change))
	# Change the color
	_start_vertex.color = COLOR_VISITING
		
	# Step 2: Initialize the queue
	var Q = []
	Q.push_back(_start_vertex)

	
	# Step 3: Start searching
	while Q:
		var u = Q.pop_front()
		
		# Process vertex
		for v in u.get_neighbor_vertices():
			if v.color == COLOR_NOT_DISCOVERED:
				# need to save the color in case the computer does multiple lines together.
				var v_color_before_change = v.color
				# log the color change
				timeline.append(ChangeVertexColorAction.new(v, COLOR_VISITING, v_color_before_change))
				# Change the color
				v.color = COLOR_VISITING

				Q.push_back(v)
		
		# need to save the color in case the computer does multiple lines together.
		var u_color_before_change = u.color
		# log the color change
		timeline.append(ChangeVertexColorAction.new(u, COLOR_FINISHED, u_color_before_change))
		# Change the color
		u.color = COLOR_FINISHED

	# Return the timeline				
	return timeline
