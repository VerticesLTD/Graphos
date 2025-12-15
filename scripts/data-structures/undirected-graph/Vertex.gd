## Represents a vertex (node) in a graph.
## Stores adjacency information and algorithm metadata.
## This class is data-oriented and intentionally not a Node.
class_name Vertex

## Constant used to represent infinity in graph algorithms.
const INF: float = 1e18

## Unique identifier of the vertex.
var id: int

## Optional visualization color.
var color: Color = Color.WHITE

## Number of incident edges.
var degree: int = 0

## Head of the adjacency list (linked list of Edge).
var edges: Edge = null

## Distance value (used by shortest-path algorithms).
var distance: float = INF

## Parent vertex (nullable, used by traversals and MST).
var parent: Vertex = null

## Key value (used by Prim’s algorithm).
var key: float = INF

## Optional x-coordinate (layout / visualization).
var x: float = 0.0

## Optional y-coordinate (layout / visualization).
var y: float = 0.0

## Constructs a new Vertex.
## @param _id        Unique vertex identifier.
## @param _color     Optional color.
## @param _distance  Initial distance value.
## @param _key       Initial key value.
## @param _x         Optional x-coordinate.
## @param _y         Optional y-coordinate.
func _init(
	_id: int,
	_color: Color = Color.WHITE,
	_distance: float = INF,
	_key: float = INF,
	_x: float = 0.0,
	_y: float = 0.0
) -> void:
	id = _id
	color = _color
	distance = _distance
	key = _key
	x = _x
	y = _y


## Adds an outgoing edge from this vertex to the destination vertex.
## If an edge already exists, no modification is performed.
## @param dest   Destination vertex.
## @param weight Weight assigned to the edge.
func connect_vertices(dest: Vertex, weight: int = 1) -> void:
	var curr: Edge = edges
	while curr:
		if curr.dst == dest:
			return
		curr = curr.next

	var e: Edge = Edge.new(weight, self, dest, edges)
	edges = e
	degree += 1

## Removes the outgoing edge to the given destination vertex.
## @param dest Destination vertex.
## @return true if an edge was removed, false otherwise.
func delete_edge(dest: Vertex) -> bool:
	var prev: Edge = null
	var curr: Edge = edges

	while curr:
		if curr.dst == dest:
			if prev == null:
				edges = curr.next
			else:
				prev.next = curr.next

			degree -= 1
			return true

		prev = curr
		curr = curr.next

	return false

## Returns all outgoing edges as an Array.
## NOTE:
## Godot does not support Array[Edge] typing.
func get_neighbors_edges() -> Array:
	var out: Array = []
	var e: Edge = edges
	while e:
		out.append(e)
		e = e.next
	return out
	
	## Returns all vertices neighbors as an Array.
func get_neighbor_vertices() -> Array:
	var neighbors: Array = []
	var e: Edge = edges 
	while e:
		neighbors.append(e.dst)
		e = e.next
	return neighbors
