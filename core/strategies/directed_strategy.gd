class_name DirectedStrategy extends ConnectionStrategy
## Strategy for creating one-way (directed) edges.
## Connects the source to the destination, but not vice versa.

## Adds a directed edge and encodes it with its specific sandbox properties.
func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: float, is_weighted: bool, shout: bool) -> void:
	# Create the logical link (pass 'self' for the strategy)
	var edge = src.connect_to(dst, is_weighted, weight, self) 
	if edge:
		graph._on_edge_added(edge)

	# If UI updates are allowed, draw the line on the screen
	if shout and edge:
		graph.spawn_edge_view(edge) 
		graph.num_edges += 1

## Deletes the one-way mathematical link and triggers visual cleanup.
func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	# Disconnect one way
	var edge: Edge = src_node.disconnect_from(dst_node)
	
	if edge: 
		graph._on_edge_removed(edge)
		edge.vanished.emit(src_node) # Tell the UI to self-destruct
		graph.num_edges -= 1


## Directed edges are unique, so we clone every single one we find.
func clone_edges(_source_graph: Graph, target_graph: Graph, vertices: Array[Vertex]) -> void:
	for v in vertices:
		var e = v.edges
		while e:
			if target_graph.vertices.has(e.dst.id):
				target_graph.add_edge(e.src.id, e.dst.id, e.weight, self, e.is_weighted, false)
			e = e.next

## Directed edges pointing at us are entirely unique and must be saved.
func requires_incoming_capture() -> bool:
	return true
	
func should_paste_edge(_src_id: int, _dst_id: int) -> bool:
	return true # Directed edges are unique, always paste.


func get_connection_error(graph: Graph, src: Vertex, dst: Vertex) -> String:
	var existing = graph.get_edge(src, dst)
	if existing and existing.strategy.get_script() != self.get_script():
		return "A non-directed edge already exists here."
	return ""
