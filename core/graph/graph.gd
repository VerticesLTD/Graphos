## Core graph data structure — adjacency-list based, strategy-pattern driven.
##
## Responsibilities of this file:
##   - Vertex and edge lifecycle (add, delete, restore, clear)
##   - Public lookup API (get_vertex, get_edge, get_vertex_id_at, etc.)
##   - Spawning UI views when running as a scene node
##   - Keeping indexes in sync (delegates to GraphEdgeIndex + GraphVertexSpatialIndex)
##   - Algorithm prep helpers (reset_for_algorithm, etc.)
##
## What lives ELSEWHERE:
##   - GraphAnalysis     — read-only queries (is_weakly_connected, weight state, etc.)
##   - GraphEdgeIndex    — incoming cache + direct edge map (graphs/core/indexes/)
##   - GraphVertexSpatialIndex — fast vertex pick grid (graphs/core/indexes/)
extends Node2D
class_name Graph

const EDGE_VIEW_SCENE   = preload("uid://bmti1ysdlhopk")
const VERTEX_VIEW_SCENE = preload("uid://cxt6f2vgtos0c")
const VERTEX_SPATIAL_INDEX_SCRIPT = preload("res://core/graph/indexes/graph_vertex_spatial_index.gd")
const EDGE_INDEX_SCRIPT           = preload("res://core/graph/indexes/graph_edge_index.gd")
const GRAPH_ANALYSIS_SCRIPT       = preload("res://core/graph/graph_analysis.gd")

# ------------------------------------------------------------------
# State
# ------------------------------------------------------------------

var vertices: Dictionary = {}  ## int -> Vertex
var free_ids: Array[int] = []  ## Recycled IDs from deleted vertices, kept sorted
var _next_vertex_id: int = 0   ## Next fresh ID when free_ids is empty

const _VERTEX_GRID_CELL_SIZE := 64.0
var _vertex_spatial_index = VERTEX_SPATIAL_INDEX_SCRIPT.new(_VERTEX_GRID_CELL_SIZE)
var _edge_index = EDGE_INDEX_SCRIPT.new()

var num_edges: int = 0
var num_vertices: int:
	get: return vertices.size()


# ------------------------------------------------------------------
# Vertex lifecycle
# ------------------------------------------------------------------

## Creates a vertex, registers it in all indexes, and spawns a view node.
func add_vertex(pos: Vector2 = Vector2.ZERO, color: Color = Globals.VERTEX_COLOR) -> Vertex:
	var v := Vertex.new(get_next_available_id(), color, Globals.INF, Globals.INF, pos)
	_register_and_visualize(v)
	return v


## Restores a previously deleted vertex (used by Undo/Redo).
func restore_vertex(v: Vertex) -> void:
	if not v or vertices.has(v.id):
		return
	free_ids.erase(v.id)
	_register_and_visualize(v)


## Deletes a vertex and all its edges cleanly, then recycles the ID.
func delete_vertex(v: Vertex) -> void:
	if not v or not vertices.has(v.id):
		return

	# Remove outgoing edges first.
	# We snapshot neighbors because the linked list mutates during deletion.
	var neighbors = v.get_outgoing_neighbors()
	for neighbor in neighbors:
		delete_edge(v.id, neighbor.id)

	# Remove remaining incoming directed edges.
	# (UndirectedStrategy already cleaned up its twins in the step above.)
	for e in get_incoming_edges(v):
		delete_edge(e.src.id, v.id)

	# Recycle ID, update indexes, kill the view.
	free_ids.append(v.id)
	free_ids.sort()  # Keep sorted so the lowest recycled ID is always reused first.
	_untrack_vertex_from_spatial_index(v.id)
	_disconnect_vertex_movement_signal(v)
	_edge_index.unregister_vertex(v.id)
	v.vanished.emit(v)  # The UIVertexView hears this and calls queue_free on itself.
	vertices.erase(v.id)


## Pops the lowest available vertex ID (recycled or brand new).
func get_next_available_id() -> int:
	if not free_ids.is_empty():
		return free_ids.pop_front()
	var id := _next_vertex_id
	_next_vertex_id += 1
	return id


# ------------------------------------------------------------------
# Edge lifecycle
# ------------------------------------------------------------------

## Adds an edge via the given strategy.
## Pass shout=false to suppress errors (used when building imposter/data-only graphs).
func add_edge(src_id: int, dst_id: int, weight: float, target_strategy: ConnectionStrategy, is_weighted: bool, shout: bool = true) -> void:
	if src_id == dst_id:
		if shout:
			Notify.show_error("Self-loops are not allowed.")
		return

	if has_edge(src_id, dst_id):
		return

	var v_src = vertices.get(src_id)
	var v_dst = vertices.get(dst_id)
	if not v_src or not v_dst:
		return

	var specific_error = target_strategy.get_connection_error(self, v_src, v_dst)
	if specific_error != "":
		if shout:
			Notify.show_error(specific_error)
		return

	target_strategy.add_edge(self, v_src, v_dst, weight, is_weighted, shout)


## Removes an edge using its own strategy (so both sides are cleaned up correctly).
func delete_edge(src_id: int, dst_id: int) -> void:
	var src_node = vertices.get(src_id)
	var dst_node = vertices.get(dst_id)
	if not src_node or not dst_node:
		return
	var edge = get_edge(src_node, dst_node)
	if not edge or not edge.strategy:
		return
	edge.strategy.delete_edge(self, src_node, dst_node)


## Spawns an edge view node. Called by strategies after they create the data edge.
func spawn_edge_view(edge_data: Edge) -> UIEdgeView:
	var edge_view = EDGE_VIEW_SCENE.instantiate()
	edge_view.edge_data = edge_data
	add_child(edge_view)
	move_child(edge_view, 0)  # Keep edge lines drawn behind vertex circles.
	return edge_view


# ------------------------------------------------------------------
# Lookups  (fast — backed by indexes)
# ------------------------------------------------------------------

func get_vertex(id: int) -> Vertex:
	return vertices.get(id) as Vertex

func get_edge(u: Vertex, v: Vertex) -> Edge:
	return _edge_index.get_edge(u.id, v.id)

func has_edge(src_id: int, dst_id: int) -> bool:
	return _edge_index.has_edge(src_id, dst_id)

## Returns all edges pointing TO this vertex (incoming adjacency).
func get_incoming_edges(target: Vertex) -> Array[Edge]:
	return _edge_index.get_incoming_edges(target.id)

## Finds the vertex whose circle contains pos. Returns NOT_FOUND if none.
func get_vertex_id_at(pos: Vector2) -> int:
	var radius_sq := Globals.VERTEX_RADIUS * Globals.VERTEX_RADIUS
	for id in _vertex_spatial_index.get_candidate_ids(pos):
		var v: Vertex = vertices.get(id)
		if v == null:
			continue
		if (v.pos - pos).length_squared() <= radius_sq:
			return v.id
	return Globals.NOT_FOUND

## Finds the closest edge segment to mouse_pos within threshold world units.
func get_edge_at(mouse_pos: Vector2, threshold: float = 12.0) -> Edge:
	var best: Edge = null
	var best_d2: float = threshold * threshold
	for v: Vertex in vertices.values():
		var e: Edge = v.edges
		while e:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(mouse_pos, e.src.pos, e.dst.pos)
			var d2: float = (mouse_pos - closest).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best = e
			e = e.next
	return best

## Returns true when the active toolbar strategy is directed.
func is_directed() -> bool:
	return Globals.active_strategy is DirectedStrategy


# ------------------------------------------------------------------
# Analysis  (delegates to GraphAnalysis — no mutation here)
# ------------------------------------------------------------------

func get_vertex_strategy(v: Vertex) -> ConnectionStrategy:
	return GRAPH_ANALYSIS_SCRIPT.get_vertex_strategy(self, v)

func get_vertex_weight_state(v: Vertex) -> Globals.WeightState:
	return GRAPH_ANALYSIS_SCRIPT.get_vertex_weight_state(self, v)

func get_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	return GRAPH_ANALYSIS_SCRIPT.get_selection_strategy(source_vertices)

func get_valid_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	return GRAPH_ANALYSIS_SCRIPT.get_valid_selection_strategy(source_vertices)

func get_graph_dominant_strategy() -> ConnectionStrategy:
	return GRAPH_ANALYSIS_SCRIPT.get_graph_dominant_strategy(self)

func get_graph_weight_state() -> Variant:
	return GRAPH_ANALYSIS_SCRIPT.get_graph_weight_state(self)

func is_weakly_connected() -> bool:
	return GRAPH_ANALYSIS_SCRIPT.is_weakly_connected(self)


# ------------------------------------------------------------------
# Subgraph / copy helpers
# ------------------------------------------------------------------

## Creates a data-only (imposter) graph containing a subset of vertices and
## the edges between them. Used for clipboard, algorithms, and preset I/O.
func create_induced_subgraph_from_vertices(source_vertices: Array[Vertex]) -> Graph:
	var imposter_graph := Graph.new()

	for v in source_vertices:
		var imposter_v := Vertex.new(v.id, v.color, v.distance, v.key, v.pos, true)
		imposter_graph.vertices[v.id] = imposter_v

	var selection_ids: Dictionary = {}
	for v in source_vertices:
		selection_ids[v.id] = true

	for v in source_vertices:
		var e = v.edges
		while e:
			if selection_ids.has(e.dst.id):
				# Guard against undirected twins adding the same edge twice.
				if not imposter_graph.has_edge(e.src.id, e.dst.id):
					imposter_graph.add_edge(e.src.id, e.dst.id, e.weight, e.strategy, e.is_weighted, false)
			e = e.next

	return imposter_graph


# ------------------------------------------------------------------
# Algorithm reset helpers
# ------------------------------------------------------------------

## Resets all algorithm-visible vertex state (distance, key, parent, color).
func reset_for_algorithm() -> void:
	for v: Vertex in vertices.values():
		v.distance = Globals.INF
		v.key = Globals.INF
		v.parent = null
		v.color = Globals.VERTEX_COLOR

func reset_distances(value: float = Globals.INF) -> void:
	for v: Vertex in vertices.values():
		v.distance = value

func reset_parents() -> void:
	for v: Vertex in vertices.values():
		v.parent = null

func reset_keys(value: float = Globals.INF) -> void:
	for v: Vertex in vertices.values():
		v.key = value


# ------------------------------------------------------------------
# Unique-edge enumeration  (used by analysis helpers + strategies)
# ------------------------------------------------------------------

## Returns one representative Edge per logical connection.
## Undirected edges are stored as two arcs (A→B and B→A), so we deduplicate
## by sorting endpoints — ensures strategy/weight checks see each pair once.
func _get_unique_edges() -> Array[Edge]:
	var list: Array[Edge] = []
	var seen: Dictionary = {}
	for v in vertices.values():
		var e: Edge = v.edges
		while e:
			var key: String
			if e.strategy is UndirectedStrategy:
				key = "U:%d:%d" % [mini(e.src.id, e.dst.id), maxi(e.src.id, e.dst.id)]
			else:
				key = "D:%d:%d" % [e.src.id, e.dst.id]
			if not seen.has(key):
				seen[key] = true
				list.append(e)
			e = e.next
	return list


# ------------------------------------------------------------------
# Lifecycle / cleanup
# ------------------------------------------------------------------

## Wipes all graph state — vertices, edges, indexes, ID pool.
## Also signals all live view nodes (UIEdgeView, UIVertexView) to queue_free()
## so that a subsequent restore doesn't leave ghost visuals on screen.
func clear() -> void:
	for v: Vertex in vertices.values():
		# Walk the outgoing edge list and signal each arc's view to self-destruct.
		# queue_free() is deferred so the linked list remains valid during iteration.
		var e: Edge = v.edges
		while e:
			e.vanished.emit(v)
			e = e.next
		_disconnect_vertex_movement_signal(v)
		v.vanished.emit(v)
	vertices.clear()
	_vertex_spatial_index.clear()
	_edge_index.clear()
	free_ids.clear()
	_next_vertex_id = 0
	num_edges = 0


## Godot predelete hook — disconnects signals before memory is freed.
## Child nodes (views) are automatically freed by Godot after this.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for v in vertices.values():
			if is_instance_valid(v):
				_disconnect_vertex_movement_signal(v)
				v.vanished.emit(v)
		vertices.clear()
		_vertex_spatial_index.clear()
		_edge_index.clear()
		free_ids.clear()


# ------------------------------------------------------------------
# Internal — index maintenance  (called by strategies + signal handlers)
# ------------------------------------------------------------------

## Called by connection strategies right after they create an edge object.
func _on_edge_added(edge: Edge) -> void:
	_edge_index.on_edge_added(edge)


## Called by connection strategies right before they destroy an edge object.
func _on_edge_removed(edge: Edge) -> void:
	_edge_index.on_edge_removed(edge)


func _register_and_visualize(v: Vertex) -> void:
	vertices[v.id] = v
	_next_vertex_id = maxi(_next_vertex_id, v.id + 1)
	_edge_index.register_vertex(v.id)
	_track_vertex_in_spatial_index(v)
	_connect_vertex_movement_signal(v)
	if v.is_imposter:
		return  # Imposter graphs are data-only — no UI nodes needed.
	var view: UIVertexView = VERTEX_VIEW_SCENE.instantiate()
	view.vertex_data = v
	add_child(view)


func _track_vertex_in_spatial_index(v: Vertex) -> void:
	_vertex_spatial_index.track_vertex(v.id, v.pos)


func _untrack_vertex_from_spatial_index(vertex_id: int) -> void:
	_vertex_spatial_index.untrack_vertex(vertex_id)


func _connect_vertex_movement_signal(v: Vertex) -> void:
	if v == null or v.is_imposter:
		return
	if not v.position_changed.is_connected(_on_vertex_position_changed):
		v.position_changed.connect(_on_vertex_position_changed)


func _disconnect_vertex_movement_signal(v: Vertex) -> void:
	if v == null or v.is_imposter:
		return
	if v.position_changed.is_connected(_on_vertex_position_changed):
		v.position_changed.disconnect(_on_vertex_position_changed)


func _on_vertex_position_changed(v: Vertex, old_pos: Vector2, new_pos: Vector2) -> void:
	_vertex_spatial_index.on_vertex_moved(v.id, old_pos, new_pos)
