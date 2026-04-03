class_name UndirectedStrategy extends ConnectionStrategy
## Strategy for creating two-way (undirected) edges.
## Logically creates two identical edges pointing at each other.

## Adds two edges (A->B and B->A) but only spawns one visual representation.
func add_edge(_graph: Graph, src: Vertex, dst: Vertex, weight: float, is_weighted: bool, shout: bool) -> void:
	# Create the links (pass and 'self' for the strategy)
	var edge_a = src.connect_to(dst, is_weighted, weight, self) 
	var edge_b = dst.connect_to(src, is_weighted, weight, self) 
	if edge_a:
		_graph._on_edge_added(edge_a)
	if edge_b:
		_graph._on_edge_added(edge_b)

	# If UI updates are allowed, draw the line for ONLY one of them
	if shout and edge_a and edge_b:
		_graph.spawn_edge_view(edge_a)
		_graph.num_edges += 1

## Deletes both the forward and backward edge links.
func delete_edge(_graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	# Disconnect both ways
	var edge_a: Edge = src_node.disconnect_from(dst_node)
	var edge_b: Edge = dst_node.disconnect_from(src_node)
	if edge_a:
		_graph._on_edge_removed(edge_a)
	if edge_b:
		_graph._on_edge_removed(edge_b)

	# Tell the UI to self-destruct
	# Whichever one has the 'UIEdgeView' listening will trigger the queue_free().
	if edge_a: edge_a.vanished.emit(src_node)
	if edge_b: edge_b.vanished.emit(dst_node)
	
	if edge_a or edge_b:
		_graph.num_edges -= 1


## Undirected edges are mirrored, so we only clone when src.id < dst.id to avoid duplicates.
func clone_edges(_source_graph: Graph, target_graph: Graph, vertices: Array[Vertex]) -> void:
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

func get_connection_error(graph: Graph, src: Vertex, dst: Vertex) -> String:
	# Undirected cannot coexist if ANY directed edge is in the way (forward or backward)
	if graph.has_edge(src.id, dst.id) or graph.has_edge(dst.id, src.id):
		var e1 = graph.get_edge(src, dst)
		var e2 = graph.get_edge(dst, src)
		
		if (e1 and e1.strategy.get_script() != self.get_script()) or \
		   (e2 and e2.strategy.get_script() != self.get_script()):
			return "Cannot create Undirected edge, conflict."
	return ""
