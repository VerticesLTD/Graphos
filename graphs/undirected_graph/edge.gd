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
@warning_ignore("unused_signal")
signal vanished(v: Vertex)

## Source vertex of the edge.
var src: Vertex

## Destination vertex of the edge.
var dst: Vertex

## Pointer to the next edge in the adjacency list.
## May be null if this is the last edge.
var next: Edge = null

## Lets the edge know if its an imposter to not emit drawing signals.
var is_imposter: bool = false


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
	_color: Color = Globals.EDGE_COLOR 
) -> void:
	self.weight = _weight
	self.src = _src
	self.dst = _dst
	self.next = _next
	self.color = _color
	
	# If the vertex is an imposter, this edge is an imposter too.
	if src:
		self.is_imposter = src.is_imposter

	# Only connect signals if we are REAL. 
	# This prevents dozens of useless connections in the imposter graph.
	if not is_imposter:
		if src: src.state_changed.connect(_on_vertex_changed)
		if dst: dst.state_changed.connect(_on_vertex_changed)

####################### SETTER FUNCTIONS & REACTION LOGIC #######################

var weight: int = 1:
	set(value):
		weight = value
		state_changed.emit()
		

var color: Color = Globals.EDGE_COLOR: 
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
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Callable returns a unique pointer to the function _on_vertex_changed
		# This is used to check if were deleting the right signals.
		var cb = Callable(self, "_on_vertex_changed")

		# Only dissconnect if:
		# The instance hasnt been deleted AND
		# The edge is REALLY connected with state_changed to src and dest.
		if is_instance_valid(src) and src.state_changed.is_connected(cb):
			src.state_changed.disconnect(cb)
		if is_instance_valid(dst) and dst.state_changed.is_connected(cb):
			dst.state_changed.disconnect(cb)
