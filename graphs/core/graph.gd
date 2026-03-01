## Represents a graph using adjacency lists.
## Uses strategy pattern in order to have different
## connection types between vertices.
extends Node2D
class_name Graph

const EDGE_VIEW_SCENE = preload("uid://bmti1ysdlhopk")
const VERTEX_VIEW_SCENE = preload("uid://cxt6f2vgtos0c")

var vertices: Dictionary = {} # int -> Vertex
var free_ids: Array[int] = []


var num_edges: int = 0
var num_vertices: int:
	get: return vertices.size()
		

func _ready() -> void:
	## Initialize the ID pool.
	for i in range(Globals.MAX_VERTICES):
		free_ids.append(i)

# Pops the lowest available ID from the pool
func get_next_available_id() -> int:
	if free_ids.is_empty():
		return Globals.NOT_FOUND
	# Since we populate 0 to MAX, the front is always the minimum.
	return free_ids.pop_front()		
	
# Creates a data vertex and initiates visualization
func add_vertex(pos: Vector2 = Vector2.ZERO, color: Color = Globals.VERTEX_COLOR) -> Vertex:
	if vertices.size() >= Globals.MAX_VERTICES:
		Notify.show_error("Vertex limit reached (Max: %d). Try deleting some?" % Globals.MAX_VERTICES)
		return null
		
	var v = Vertex.new(get_next_available_id(), color, Globals.INF, Globals.INF, pos)		
	_register_and_visualize(v)
	
	return v

## Helper to handle dictionary storage and UI spawning
func _register_and_visualize(v: Vertex) -> void:
	vertices[v.id] = v
	
	if v.is_imposter: return # Imposters don't need a UI representation
	
	var view: UIVertexView = VERTEX_VIEW_SCENE.instantiate()
	view.vertex_data = v

	add_child(view)


# Restores a vertex (useful for Undo/Redo)
func restore_vertex(v: Vertex) -> void:
	if not v or vertices.has(v.id): return
	free_ids.erase(v.id) 
	_register_and_visualize(v)
	

# Cleans up a vertex and recycles its ID
func delete_vertex(v: Vertex) -> void:
	if not v or not vertices.has(v.id): return

	# Strategy handles the actual edge logic (source vs destination)
	for neighbor in v.get_neighbor_vertices():
		delete_edge(v.id, neighbor.id)

	free_ids.append(v.id)
	free_ids.sort() # Ensure the next ID taken is the lowest
	
	v.vanished.emit(v) # View hears this and deletes itself
	vertices.erase(v.id)


## Adds an edge between two existing vertices via the currect strategy.
## @param shout: If false, creates data-only edges for imposters.
func add_edge(src_id: int, dst_id: int, weight: int, strategy: ConnectionStrategy, is_weighted: bool, shout: bool = true) -> void:
	if src_id == dst_id or has_edge(src_id, dst_id): return

	var v_src = vertices.get(src_id)
	var v_dst = vertices.get(dst_id)
	
	if not v_src or not v_dst: return

	# Delegate the logic and the shouting behavior to the strategy
	strategy.add_edge(self, v_src, v_dst, weight, is_weighted, shout)
	
# Adds an Edge View to the scene
func spawn_edge_view(edge_data: Edge) -> UIEdgeView:
	var edge_view = EDGE_VIEW_SCENE.instantiate()
	edge_view.edge_data = edge_data
	add_child(edge_view)
	move_child(edge_view, 0) # Keep lines behind the vertex circles
	return edge_view
				

## Removes an edge between two vertices.
func delete_edge(src_id: int, dst_id: int) -> void:
	var src_node = vertices.get(src_id)
	var dst_node = vertices.get(dst_id)
	if not src_node or not dst_node: return
	
	var edge = get_edge(src_node, dst_node)
	if not edge or not edge.strategy: return
	
	# Delete the edge with the correct strategy
	edge.strategy.delete_edge(self, src_node, dst_node)	

## Returns the Vertex object associated with the given ID(or null if none exist).
func get_vertex(id: int) -> Vertex:
	return vertices.get(id) as Vertex
	
## Returns the edge connecting u and v, or null if none exists.
func get_edge(u: Vertex, v: Vertex) -> Edge:
	var e = u.edges
	while e:
		if e.dst == v: return e
		e = e.next
	return null
	
## Returns a vertex "touching" the given position, or null if none exist
func get_vertex_id_at(pos: Vector2) -> int:
	# Optional, add a parameter for the vertex radius
	for v: Vertex in vertices.values():
		if v.pos.distance_to(pos) <= Globals.VERTEX_RADIUS:
			return v.id
	return Globals.NOT_FOUND

## Returns true if an edge exists between two vertices.
func has_edge(src_id: int, dst_id: int) -> bool:
	var v: Vertex = vertices.get(src_id)
	if not v: return false
	var e = v.edges
	while e:
		if e.dst.id == dst_id: return true
		e = e.next
	return false

## Returns the closest Edge under the mouse, or null if none is close enough.
## threshold is in world units (same coordinate space as Vertex.pos).
func get_edge_at(mouse_pos: Vector2, threshold: float = 12.0) -> Edge:
	var best: Edge = null
	var best_d2: float = threshold * threshold

	for v: Vertex in vertices.values():
		var e: Edge = v.edges
		while e:
			var a: Vector2 = e.src.pos
			var b: Vector2 = e.dst.pos
			
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(mouse_pos, a, b)
			var d2: float = (mouse_pos - closest).length_squared()

			# Strictly less than (<). If we check the reverse edge later and it's 
			# the exact same distance, it just ignores it.
			if d2 < best_d2: 
				best_d2 = d2
				best = e

			e = e.next

	return best
	
	
## Validates that all edges in the selection share the same strategy.
## Returns the shared ConnectionStrategy, or null if the selection is mixed.
func get_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	var shared_strategy: ConnectionStrategy = null
	
	# Mapping for fast lookup
	var subset_ids: Dictionary = {}
	for v in source_vertices:
		subset_ids[v.id] = true

	for v in source_vertices:
		var e = v.edges
		while e:
			# Only evaluate edges where both endpoints are in the selection
			if subset_ids.has(e.dst.id):
				if shared_strategy == null:
					shared_strategy = e.strategy
				elif e.strategy != shared_strategy:
					return null # Mixed types found
			e = e.next

	return shared_strategy


## Validates the selection and returns the shared strategy, or shows an error.
func get_valid_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	var strategy = get_selection_strategy(source_vertices)
	
	if strategy == null:
		Notify.show_error("Mixed Graph Error: Please select edges of only one type (Directed OR Undirected).")
		return null
		
	return strategy
	
## Returns a new sub-graph from given vertices
## This graph is 'Data-Only' and will not appear on screen.
func create_induced_subgraph_from_vertices(source_vertices: Array[Vertex]) -> Graph:
	var strategy = get_selection_strategy(source_vertices)
	if not strategy: return null # Safety check

	var imposter_graph = Graph.new()
	
	# Clone the Nodes
	for v in source_vertices:
		var imposter_v = Vertex.new(v.id, v.color, v.distance, v.key, v.pos, true)
		imposter_graph.vertices[v.id] = imposter_v

	# DELEGATION: Let the strategy build the edges its own way
	strategy.clone_edges(self, imposter_graph, source_vertices)
	
	return imposter_graph
		
## Resets the graph to its base state for algorithm visualizers
func reset_for_algorithm() -> void:
	for v: Vertex in vertices.values():
		v.distance = Globals.INF
		v.key = Globals.INF
		v.parent = null
		v.color = Globals.VERTEX_COLOR # Maybe we shouldn't reset the colors

## Resets all distance values.
func reset_distances(value: float = Globals.INF) -> void:
	for v: Vertex in vertices.values():
		v.distance = value

## Clears all parent pointers.
func reset_parents() -> void:
	for v: Vertex in vertices.values():
		v.parent = null

## Resets all key values.
func reset_keys(value: float = Globals.INF) -> void:
	for v: Vertex in vertices.values():
		v.key = value

## Removes all vertices and edges from the graph.
func clear() -> void:
	vertices.clear()
	num_edges = 0

## Final cleanup before the Graph node is deleted from memory
# Final cleanup before the Graph node is deleted from memory
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for v in vertices.values():
			if is_instance_valid(v):
				v.vanished.emit(v) # Ensure UI views die first
		vertices.clear()
				
		# We don't need to manually queue_free children.
		# When this Graph (Node2D) is removed from memory, Godot automatically
		# removes all children (vertex_views and edge_views) from the Scene Tree.
