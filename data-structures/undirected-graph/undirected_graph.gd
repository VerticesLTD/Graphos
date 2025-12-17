## Represents an undirected graph using adjacency lists.
## Each undirected edge is stored internally as two directed edges.
## The edge counter tracks logical undirected edges.
class_name UndirectedGraph

## Dictionary[int -> Vertex]
## Godot does not support generic typing for dictionaries.
var vertices: Dictionary = {}

## Total number of vertices in the graph.
var num_vertices: int = 0

## Total number of undirected edges in the graph.
var num_edges: int = 0

## Removes all vertices and edges from the graph.
func clear() -> void:
	vertices.clear()
	num_vertices = 0
	num_edges = 0

## Adds a vertex to the graph if it does not already exist.
## @param id    Unique vertex identifier.
## @param x     Optional x-coordinate.
## @param y     Optional y-coordinate.
## @param color Optional color.
func add_vertex(id: int, x: float = 0.0, y: float = 0.0, color: Color = Color.WHITE) -> void:
	if not vertices.has(id):
		var v: Vertex = Vertex.new(id, color, Vertex.INF, Vertex.INF, x, y)
		vertices[id] = v
		num_vertices += 1

## Returns the vertex with the given ID.
## IMPORTANT:
## This function intentionally has NO return type annotation.
## Reason:
##   - It may return `null` if the vertex does not exist.
##   - Godot does not support nullable return types (e.g. Vertex?).
## Callers MUST explicitly handle the null case.
func get_vertex(id: int):
	return vertices.get(id)

## Returns the edge connecting u and v, or null if none exists.
func get_edge(u: Vertex, v: Vertex) -> Edge:
	var e = u.edges
	while e:
		if e.dst == v:
			return e
		e = e.next
	return null
	
## Adds an undirected edge between two existing vertices.
## @param src_id Source vertex ID.
## @param dst_id Destination vertex ID.
## @param weight Edge weight.
func add_edge(src_id: int, dst_id: int, weight: int = 1) -> void:
	var src: Vertex = vertices[src_id]
	var dst: Vertex = vertices[dst_id]

	var before: int = src.degree
	src.connect_vertices(dst, weight)
	var after: int = src.degree

	if after > before:
		dst.connect_vertices(src, weight)
		num_edges += 1

## Removes an undirected edge between two vertices.
func delete_edge(src_id: int, dst_id: int) -> void:
	if not vertices.has(src_id) or not vertices.has(dst_id):
		return

	var v1: Vertex = vertices[src_id]
	var v2: Vertex = vertices[dst_id]

	var d1: bool = v1.delete_edge(v2)
	var d2: bool = v2.delete_edge(v1)

	if d1 or d2:
		num_edges -= 1


## Removes a vertex and all incident edges.
func delete_vertex(id: int) -> void:
	if not vertices.has(id):
		return

	var victim: Vertex = vertices[id]

	var e: Edge = victim.edges
	var removed: int = 0
	while e:
		removed += 1
		e = e.next

	for v: Vertex in vertices.values():
		if v != victim:
			v.delete_edge(victim)

	num_edges -= removed
	num_vertices -= 1
	vertices.erase(id)

## Returns true if an edge exists between two vertices.
func has_edge(src_id: int, dst_id: int) -> bool:
	if not vertices.has(src_id) or not vertices.has(dst_id):
		return false

	var v: Vertex = vertices[src_id]
	var e: Edge = v.edges
	while e:
		if e.dst.id == dst_id:
			return true
		e = e.next

	return false

## Resets all distance values.
func reset_distances(value: float = Vertex.INF) -> void:
	for v: Vertex in vertices.values():
		v.distance = value

## Clears all parent pointers.
func reset_parents() -> void:
	for v: Vertex in vertices.values():
		v.parent = null

## Resets all key values.
func reset_keys(value: float = Vertex.INF) -> void:
	for v: Vertex in vertices.values():
		v.key = value

## Reset the WHOLE graph for a clean algorithm start
func reset_for_algorithm() -> void:
	reset_distances()
	reset_parents()
	reset_keys()
	
	# Additionally, reset all the colors to white 
	for v in vertices.values():
		v.color = Color.WHITE
