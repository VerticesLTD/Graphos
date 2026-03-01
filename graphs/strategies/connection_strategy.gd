class_name ConnectionStrategy extends RefCounted

## Virtual function to handle edge creation and UI spawning.
func add_edge(graph: Graph, src: Vertex, dst: Vertex, weight: int, shout: bool) -> void:
	pass

## Virtual function to handle edge deletion and UI cleanup.
func delete_edge(graph: Graph, src_node: Vertex, dst_node: Vertex) -> void:
	pass
