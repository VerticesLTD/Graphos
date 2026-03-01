class_name UndirectedStrategy extends ConnectionStrategy
## Strategy for creating two-way (undirected) edges.
## Logically creates two identical edges pointing at each other.

## Adds two edges (A->B and B->A) but only spawns one visual representation.
func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, is_weighted: bool, shout: bool) -> void:
	# Create the links (pass and 'self' for the strategy)
	var edge_a = src.connect_to(dst, is_weighted, weight, self) 
	var edge_b = dst.connect_to(src, is_weighted, weight, self) 

	# If UI updates are allowed, draw the line for ONLY one of them
	if shout and edge_a and edge_b:
		graph.spawn_edge_view(edge_a)
		graph.num_edges += 1

## Deletes both the forward and backward edge links.
func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	# Disconnect both ways
	var edge_a: Edge = src_node.disconnect_from(dst_node)
	var edge_b: Edge = dst_node.disconnect_from(src_node)

	# Tell the UI to self-destruct
	if edge_a: edge_a.vanished.emit(src_node)
	if edge_b: edge_b.vanished.emit(dst_node)
	
	if edge_a or edge_b:
		graph.num_edges -= 1


## Undirected edges are mirrored, so we only clone when src.id < dst.id to avoid duplicates.
func clone_edges(source_graph: Graph, target_graph: Graph, vertices: Array[Vertex]) -> void:
	for v in vertices:
		var e = v.edges
		while e:
			if target_graph.vertices.has(e.dst.id) and v.id < e.dst.id:
				target_graph.add_edge(e.src.id, e.dst.id, e.weight, self, e.is_weighted, false)
			e = e.next

## We return false because to prevent duplicates.
func requires_incoming_capture() -> bool:
	return false
	
func should_paste_edge(src_id: int, dst_id: int) -> bool:
	return src_id < dst_id # Only paste once to avoid duplicating A-B and B-A.
