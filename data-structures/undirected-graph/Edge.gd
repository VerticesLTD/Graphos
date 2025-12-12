##
# Represents a directed edge in a graph adjacency list.
#
# Each edge stores a reference to its source vertex, destination vertex,
# and the next edge in the adjacency list. This forms a singly-linked list.
#
# Undirected graphs store each logical edge twice (once per endpoint).
#
class_name Edge

## Weight of the edge (used by MST / shortest-path algorithms).
var weight: int = 1

## Source vertex of the edge.
var src: Vertex

## Destination vertex of the edge.
var dst: Vertex

## Pointer to the next edge in the adjacency list.
## May be null if this is the last edge.
var next: Edge = null

## Optional color metadata (useful for visualization).
var color: Color = Color.WHITE

##
# Constructs a new Edge.
#
# @param _weight Weight of the edge.
# @param _src    Source vertex.
# @param _dst    Destination vertex.
# @param _next   Next edge in the adjacency list (nullable).
# @param _color  Optional color metadata.
#
func _init(
	_weight: int = 1,
	_src: Vertex = null,
	_dst: Vertex = null,
	_next: Edge = null,
	_color: Color = Color.WHITE
) -> void:
	weight = _weight
	src = _src
	dst = _dst
	next = _next
	color = _color
