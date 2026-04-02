class_name ErrorStrategy 
extends ConnectionStrategy

## Strategy assigned dynamically when a vertex is in an illegal state 
## (e.g., it somehow got both Directed and Undirected edges attached to it).

func get_connection_error(_graph: Graph, _src: Vertex, _dst: Vertex) -> String:
	# A corrupted vertex locks down and rejects EVERYTHING until the user deletes the bad edges.
	return "Graph Error: This vertex has mixed edge types. Please delete its edges to reset it."

# --- Dummy Methods ---
func add_edge(_g: Graph, _s: Vertex, _d: Vertex, _w: float, _iw: bool, _sh: bool) -> void:
	push_error("ErrorStrategy cannot add edges!")

func delete_edge(_g: Graph, _s: Vertex, _d: Vertex) -> void:
	pass

func clone_edges(_sg: Graph, _tg: Graph, _v: Array[Vertex]) -> void:
	pass
