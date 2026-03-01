class_name DirectedStrategy extends ConnectionStrategy

func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, shout: bool) -> void:
	# Quietly update the data structure (One way only)
	var edge = src.connect_to(dst, weight) 
	
	# If UI updates are allowed, draw the line
	if shout and edge:
		var view = graph.spawn_edge_view(edge)
		edge.view = view
		graph.num_edges += 1

func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	# Delete one way
	var edge: Edge = src_node.delete_edge(dst_node)

	if edge: edge.vanished.emit()
	graph.num_edges -= 1
