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

## Signal to trigger UI animations (like hovers) from data/algorithms.
@warning_ignore("unused_signal")
signal animation_requested(anim_name: String)

## Source vertex of the edge.
var src: Vertex

## Destination vertex of the edge.
var dst: Vertex

## Pointer to the next edge in the adjacency list.
## May be null if this is the last edge.
var next: Edge = null

## Lets the edge know if its an imposter to not emit drawing signals.
var is_imposter: bool = false

## The edge type
var strategy: ConnectionStrategy

## Flag to determine if the UI should show the weight label.
var is_weighted: bool = false


## Constructs a new Edge.
## @param _weight Weight of the edge.
## @param _src    Source vertex.
## @param _dst    Destination vertex.
## @param _next   Next edge in the adjacency list (nullable).
## @param _color  Optional color metadata.
func _init(
	_src: Vertex,
	_dst: Vertex,
	_strategy: ConnectionStrategy,
	_is_weighted: bool = false,
	_weight: float = 1.0,
	_next: Edge = null,
	_color: Color = Globals.EDGE_COLOR
	) -> void:
	self.src = _src
	self.dst = _dst
	self.strategy = _strategy
	self.is_weighted = _is_weighted
	self.weight = clampf(_weight, -999.0, 999.0)
	self.next = _next
	self.color = _color

	# If the vertex is an imposter, this edge is an imposter too.
	if src:
		self.is_imposter = src.is_imposter

	# Only connect movement signals if we are a REAL edge	
		if src: src.state_changed.connect(_notify_change)
		if dst: dst.state_changed.connect(_notify_change)
		
# --- Reaction Logic ---

func _notify_change() -> void:
	if not is_imposter:
		state_changed.emit()

var weight: float = 1.0:
	set(value):
		var clamped = clampf(value, -999.0, 999.0)
		if weight == clamped: return # Early exit
		weight = clamped
		_notify_change()
		
var color: Color = Globals.EDGE_COLOR: 
	set(value):
		if color == value: return # Early exit
		color = value
		_notify_change()

	
## Helper function to fetch the other vertex
func get_other_vertex(v: Vertex) -> Vertex:
	return dst if v == src else src
	

## Disconnects signals to prevent memory leaks when deleted
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var cb = Callable(self, "_notify_change")
		if is_instance_valid(src) and src.state_changed.is_connected(cb):
			src.state_changed.disconnect(cb)
		if is_instance_valid(dst) and dst.state_changed.is_connected(cb):
			dst.state_changed.disconnect(cb)
