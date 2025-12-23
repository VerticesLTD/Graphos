## Represents a directed edge in a graph adjacency list.
## Each edge stores a reference to its source vertex, destination vertex,
## and the next edge in the adjacency list. This forms a singly-linked list.
## Undirected graphs store each logical edge twice (once per endpoint).
class_name Edge

## Emitted when values like color or position change. 
## The Sprite hears this and repaints itself.
signal state_changed

## Emitted when this edge is removed from the graph.
## The EdgeView hears this and calls queue_free().
signal vanished

## Source vertex of the edge.
var src: Vertex

## Destination vertex of the edge.
var dst: Vertex

## Pointer to the next edge in the adjacency list.
## May be null if this is the last edge.
var next: Edge = null


## Constructs a new Edge.
## @param _weight Weight of the edge.
## @param _src    Source vertex.
## @param _dst    Destination vertex.
## @param _next   Next edge in the adjacency list (nullable).
## @param _color  Optional color metadata.
func _init(
	_weight: int = 1,
	_src: Vertex = null,
	_dst: Vertex = null,
	_next: Edge = null,
	_color: Color = Color.RED
) -> void:
	self.weight = _weight
	self.src = _src
	self.dst = _dst
	self.next = _next
	self.color = _color

	# The Edge spyies on its vertices to know where to move(only if they exist)
	if src:
		src.state_changed.connect(_on_vertex_changed)
	if dst:
		dst.state_changed.connect(_on_vertex_changed)

####################### SETTER FUNCTIONS & REACTION LOGIC #######################

## Long explanation on why and how use setters in Vertex class

var weight: int = 1:
	set(value):
		weight = value
		state_changed.emit()
		

var color: Color = Color.RED:
	set(value):
		color = value
		state_changed.emit()


func _on_vertex_changed() -> void:
	# If a vertex "shouts" that it moved, the Edge 
	# shouts too so the Line Sprite knows to stretch.
	state_changed.emit()

## Helper function to fetch the other vertex, 
## used when we have an edge and want to get its dst
## @param v		Returns the vertex at the opposite end of this edge relative to v.
func get_other_vertex(v: Vertex) -> Vertex:
	if v == src:
		return dst
	else:
		return src

## This is called right before the object is removed from memory.
## Disconnects edge from being callable(Object doesnt do it alone but its object is lighter and faster).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Use a Callable to ensure the reference is stable
		var cb = Callable(self, "_on_vertex_changed")

		if is_instance_valid(src) and src.state_changed.is_connected(cb):
			src.state_changed.disconnect(cb)
		if is_instance_valid(dst) and dst.state_changed.is_connected(cb):
			dst.state_changed.disconnect(cb)
