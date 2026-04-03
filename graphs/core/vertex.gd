class_name Vertex

## Emitted when values like color or position change (UI repaints).
signal state_changed

## Emitted when removed from the graph (UI calls queue_free).
@warning_ignore("UNUSED_SIGNAL")
signal vanished(v: Vertex)

## Dedicated movement signal so Graph can update spatial indexes without
## rescanning every vertex each query.
@warning_ignore("unused_signal")
signal position_changed(v: Vertex, old_pos: Vector2, new_pos: Vector2)

## This lets algorithms say vertex.animation_requested.emit("hover_start")
@warning_ignore("unused_signal")
signal animation_requested(anim_name: String)

var id: int 
var degree: int = 0 
var edges: Edge = null 

## If true, acts as a "Data Proxy" for algorithms (no UI signals emitted).
var is_imposter: bool = false


## Initializes a new Vertex, bypassing setters to prevent initialization signal spam.
func _init(
	_id: int,
	_color: Color = Globals.VERTEX_COLOR,
	_distance: float = Globals.INF,
	_key: float = Globals.INF,
	_pos: Vector2 = Vector2.ZERO,
	_is_imposter: bool = false,
) -> void:
	id = _id
	color = _color
	distance = _distance
	key = _key
	pos = _pos
	is_imposter = _is_imposter
	
# --- Reaction Logic ---

## Emits state_changed only if this is a real vertex (not an imposter).
func _notify_change() -> void:
	if not is_imposter:
		state_changed.emit()

var color: Color = Globals.VERTEX_COLOR:
	set(value):
		if color == value: return # Early exit: no change, no repaint
		color = value
		_notify_change()

var distance: float = Globals.INF:
	set(value):
		if distance == value: return
		distance = value
		_notify_change()

var key: float = Globals.INF:
	set(value):
		if key == value: return
		key = value
		_notify_change()

var pos: Vector2 = Vector2.ZERO:
	set(value):
		if pos == value: return
		var old_pos := pos
		pos = value
		if not is_imposter:
			position_changed.emit(self, old_pos, value)
		_notify_change()
		
var parent: Vertex = null:
	set(value):
		if parent == value: return
		parent = value
		_notify_change()

var z_idx: int = 0:
	set(value):
		if z_idx == value: return
		z_idx = value
		_notify_change()
						
# --- Graph Operations ---

## Creates and prepends a new Edge to the destination, returning it.
func connect_to(dest: Vertex, is_weighted: bool, weight: float, strategy: ConnectionStrategy) -> Edge:
	var curr: Edge = edges
	while curr:
		if curr.dst == dest:
			return null # Prevent duplicate edges
		curr = curr.next

	var new_edge: Edge = Edge.new(self, dest, strategy, is_weighted, weight, edges)
	
	edges = new_edge
	degree += 1
	
	# Notify any listeners (like UIVertexView) that the adjacency list changed
	state_changed.emit()
	
	return new_edge
		
## Removes the bridge to the destination and returns the deleted Edge.
func disconnect_from(dest: Vertex) -> Edge:
	var prev: Edge = null
	var curr: Edge = edges

	while curr:
		if curr.dst == dest:
			if prev == null:
				edges = curr.next # Remove the head
			else:
				prev.next = curr.next # Bypass the middle/tail

			degree -= 1
			return curr 
		
		prev = curr
		curr = curr.next
	
	return null
		
# --- Helpers & Cleanup ---

## Returns an array of all outgoing Edge objects.
func get_outgoing_edges() -> Array[Edge]:
	var out: Array[Edge] = []
	var e: Edge = edges
	while e:
		out.append(e)
		e = e.next
	return out
	
## Returns all outgoing neighbor vertices as an Array.
func get_outgoing_neighbors() -> Array[Vertex]:
	var neighbors: Array[Vertex] = []
	var e: Edge = edges
	while e:
		neighbors.append(e.dst)
		e = e.next
	return neighbors	

## Handles manual memory management for incident edges before the vertex is destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var curr: Edge = edges
		while curr:
			var next_edge: Edge = curr.next
			
			curr.vanished.emit() 
			
			# Break circular references so Godot's GC can free the memory
			curr.next = null 
			curr = next_edge
			
		edges = null
