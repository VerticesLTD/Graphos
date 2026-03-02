class_name ConnectionStrategy extends RefCounted
## Virtual base class for edge connection strategies.
## Defines the blueprint for how vertices connect and disconnect.

## Virtual function to handle edge creation, data encoding, and UI spawning.
func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, is_weighted: bool, shout: bool) -> void:
	pass

## Virtual function to handle edge deletion and UI cleanup.
func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	pass

## Clones a set of edges from the source graph into the target (imposter) graph.
## Each strategy handles its own deduplication (e.g., Undirected only adds src < dst).
func clone_edges(source_graph: Graph, target_graph: Graph, vertices: Array[Vertex]) -> void:
	pass
	
## Determines if this edge type needs to be explicitly captured when pointing TO a deleted vertex.
func requires_incoming_capture() -> bool:
	return true # Default to true for safety

## Determines if an edge should be pasted from the clipboard.
## Used to prevent undirected edges from being pasted twice.
func should_paste_edge(src_id: int, dst_id: int) -> bool:
	return true


## Validates if a connection can be made between two vertices under this strategy.
## Returns an empty String if valid, or an error message if invalid.
func get_connection_error(_graph: Graph, _src: Vertex, _dst: Vertex) -> String:
	return "" # Default allows everything. Subclasses will override this.
