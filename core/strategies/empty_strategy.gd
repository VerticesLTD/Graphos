class_name EmptyStrategy 
extends ConnectionStrategy

## Strategy assigned dynamically when a vertex has absolutely no edges.
## It acts as a blank canvas and accepts any valid connection.

func get_connection_error(_graph: Graph, _src: Vertex, _dst: Vertex) -> String:
	# An empty vertex has no rules yet, so it never vetos a connection.
	return "" 

# --- Dummy Methods (To satisfy the base class, though they should never be called) ---
func add_edge(_g: Graph, _s: Vertex, _d: Vertex, _w: float, _iw: bool, _sh: bool) -> void:
	push_error("EmptyStrategy cannot add edges!")

func delete_edge(_g: Graph, _s: Vertex, _d: Vertex) -> void:
	pass

func clone_edges(_sg: Graph, _tg: Graph, _v: Array[Vertex]) -> void:
	pass
