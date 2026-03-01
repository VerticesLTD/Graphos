class_name UndirectedStrategy extends ConnectionStrategy

func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, shout: bool) -> void:
	# Quietly update the data structures
	var edge_a = src.connect_to(dst, weight) 
	var edge_b = dst.connect_to(src, weight) 
	
	# If UI updates are allowed, draw the line and share it
	if shout and edge_a and edge_b:
		var view = graph.spawn_edge_view(edge_a)
		graph.num_edges += 1

func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	# Delete both ways
	var edge_a: Edge = src_node.disconnect_from(dst_node)
	var edge_b: Edge = dst_node.disconnect_from(src_node)

	# The UI components listen for the vanished signal to queue_free themselves
	if edge_a: edge_a.vanished.emit()
	if edge_b: edge_b.vanished.emit()
	
	graph.num_edges -= 1
