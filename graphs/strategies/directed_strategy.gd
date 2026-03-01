class_name DirectedStrategy extends ConnectionStrategy

func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, shout: bool) -> void:
	var edge = src.connect_to(dst, weight) 
	
	if shout and edge:
		graph.spawn_edge_view(edge) 
		graph.num_edges += 1

func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	var edge: Edge = src_node.delete_edge(dst_node)
	if edge: edge.vanished.emit()
	graph.num_edges -= 1
