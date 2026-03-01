## Represents a graph using adjacency lists.
## Uses strategy pattern in order to have different
## connection types between vertices.
extends Node2D
class_name Graph

# We load our "Blueprints" (Scenes) here
const EDGE_VIEW_SCENE = preload("uid://bmti1ysdlhopk")
const VERTEX_VIEW_SCENE = preload("uid://cxt6f2vgtos0c")


## Dictionary[int -> Vertex]
var vertices: Dictionary = {}

var free_ids: Array[int] = []

## The Context maintains a reference to one of the concrete strategies
var strategy: ConnectionStrategy = UndirectedStrategy.new()

## Setter for the strategy in order to change it
func set_strategy(new_strategy: ConnectionStrategy) -> void:
	self.strategy = new_strategy
	
## Metadata counters, num_vertices shouldn't be taken 
## care of manually because we can get it by using size
var num_vertices: int:
	get:
		return vertices.size()
		
var num_edges: int = 0

## Internal counter to ensure every vertex gets a unique, incremental ID
var _next_vertex_id: int = 0

	
func _ready() -> void:
	for i in range(Globals.MAX_VERTICES):
		free_ids.append(i)

## Returns the next available id
func get_next_available_id() -> int:
	if free_ids.is_empty():
		return Globals.NOT_FOUND
	
	return free_ids.pop_front()
		
## ------------------------------------------------------------------------------
## SIGNAL REACTION, edge/vertex add/remove
## ------------------------------------------------------------------------------	

	
## ------------------------------------------------------------------------------
## GRAPH OPERATIONS 
## ------------------------------------------------------------------------------
	
	
## ------------------------------------------------------------------------------
## ADD VERTEX
## ------------------------------------------------------------------------------

## Public: Create brand new vertex

func add_vertex(pos: Vector2 = Vector2.ZERO, color: Color = Globals.VERTEX_COLOR) -> Vertex:
	if vertices.size() >= Globals.MAX_VERTICES:
		Notify.show_error("Vertex limit reached (Max: %d). Try deleting some?" % Globals.MAX_VERTICES)
		return null
		
	var id = get_next_available_id()

	var v = Vertex.new(id, color, Vertex.INF, Vertex.INF, pos)
		
	_register_and_visualize(v)
	return v

## Public: Restore from Undo/Redo
func restore_vertex(v: Vertex) -> void:
	if not v or vertices.has(v.id): return
	
	free_ids.erase(v.id) # Id is no longer free
	
	_register_and_visualize(v)

## Private Helper: handles VertexView and vertices dictionary
func _register_and_visualize(v: Vertex) -> void:
	vertices[v.id] = v
	
	var view: UIVertexView = VERTEX_VIEW_SCENE.instantiate()

	# Dependency injection
	view.vertex_data = v 
	v.view = view

	add_child(view)
	
	
## ------------------------------------------------------------------------------
## DELETE VERTEX
## ------------------------------------------------------------------------------


## Removes a vertex and all incident edges.
## The signals triggered here handle the cleanup of both visuals and metadata.
func delete_vertex(vertex: Vertex) -> void:
	# 1. Safety check
	if not vertex or not vertices.has(vertex.id):
		return

	# 2. Clean up connections
	var neighbors = vertex.get_neighbor_vertices()
	for neighbor_v in neighbors:
		delete_edge(vertex.id, neighbor_v.id)

	# Add the id to free ids
	free_ids.append(vertex.id)
	free_ids.sort()
	
	# Signal deletion (Metadata + UI)
	vertex.vanished.emit(vertex)

	# Internal cleanup
	vertices.erase(vertex.id)


## ------------------------------------------------------------------------------
## ADD EDGE
## ------------------------------------------------------------------------------

## Adds an edge between two existing vertices. 
## @param shout: If false, creates data-only edges for imposters.
func add_edge(src_id: int, dst_id: int, weight: int = 1, shout: bool = true) -> void:
	if src_id == dst_id or has_edge(src_id, dst_id):
		return

	var v_src = vertices.get(src_id)
	var v_dst = vertices.get(dst_id)
	
	if not v_src or not v_dst: return

	# Delegate the logic and the shouting behavior to the strategy
	strategy.add_edge(self, v_src, v_dst, weight, shout)		

## Called by the Strategy to physically draw the line on the screen
func spawn_edge_view(edge_data: Edge) -> UIEdgeView:
	var edge_view = EDGE_VIEW_SCENE.instantiate()
	edge_view.edge_data = edge_data
	add_child(edge_view)
	
	# Draw behind vertices
	move_child(edge_view, 0) 
	return edge_view
			
## ------------------------------------------------------------------------------
## DELETE EDGE
## ------------------------------------------------------------------------------

## Removes an edge between two vertices.
func delete_edge(src_id: int, dst_id: int) -> void:
	var src_node = vertices.get(src_id)
	var dst_node = vertices.get(dst_id)

	if not src_node or not dst_node:
		return

	# DELEGATION: The strategy decides if it deletes one way or both ways!
	strategy.delete_edge(self, src_node, dst_node)
	
			
## Removes all vertices and edges from the graph.
func clear() -> void:
	vertices.clear()
	num_edges = 0


## ------------------------------------------------------------------------------
## GETTERS
## ------------------------------------------------------------------------------

## Returns the Vertex object associated with the given ID.
## Returns null if the ID is not found in the graph.
## Callers must check if v: , to ensure its not null(it is if it wasnt found).
func get_vertex(id: int) -> Vertex:
	return vertices.get(id) as Vertex

## Returns the edge connecting u and v, or null if none exists.
func get_edge(u: Vertex, v: Vertex) -> Edge:
	var e = u.edges
	while e:
		if e.dst == v:
			return e
		e = e.next
	return null

## Iterates over vertices to check if position is colliding with one of them.
func get_vertex_id_at(pos: Vector2) -> int:
	for v: Vertex in vertices.values():
		if v.pos.distance_to(pos) <= Globals.VERTEX_RADIUS:
			return v.id
	return Globals.NOT_FOUND

## Returns the closest Edge under the mouse, or null if none is close enough.
## threshold is in world units (same coordinate space as Vertex.pos).
func get_edge_at(mouse_pos: Vector2, threshold: float = 12.0) -> Edge:
	var best: Edge = null
	var best_d2: float = threshold * threshold

	## Deduplicate undirected edges using a typed key (lo_id, hi_id)
	var seen: Dictionary = {}

	for v: Vertex in vertices.values():
		var e: Edge = v.edges
		while e:
			var a_id: int = e.src.id
			var b_id: int = e.dst.id

			var lo: int
			var hi: int
			if a_id < b_id:
				lo = a_id
				hi = b_id
			else:
				lo = b_id
				hi = a_id

			var key: Vector2i = Vector2i(lo, hi)

			if not seen.has(key):
				seen[key] = true

				var a: Vector2 = e.src.pos
				var b: Vector2 = e.dst.pos
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(mouse_pos, a, b)
				var d2: float = (mouse_pos - closest).length_squared()

				if d2 <= best_d2:
					best_d2 = d2
					best = e

			e = e.next

	return best


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

	# Additionally, reset all the colors
	for v in vertices.values():
		v.color = Globals.VERTEX_COLOR


## Returns a new sub-graph from given vertices
## This graph is 'Data-Only' and will not appear on screen.
func create_induced_subgraph_from_vertices(source_vertices: Array[Vertex]) -> Graph:
	var imposter_graph = Graph.new()
	
	# 1. Create the Nodes (The Ghosts)
	for v in source_vertices:
		var imposter_v = Vertex.new(
			v.id, v.color, v.distance, v.key, v.pos, true,
		)
		# Manually add it to the graph to not trigger emitions.
		imposter_graph.vertices[v.id] = imposter_v

	
	# 2. Connect the Edges (Walking the neighbors), 
	# better for efficiency than going over all vertices in imposters
	for v in source_vertices:
		for neighbor in v.get_neighbor_vertices():
			# We only connect if the neighbor is ALSO in our selection
			# and we use ID comparison to avoid connecting the same edge twice
			if imposter_graph.vertices.has(neighbor.id) and v.id < neighbor.id:
				imposter_graph.add_edge(v.id, neighbor.id, 1, false) # Pass 'false' for shout
	return imposter_graph


## Notification thats recieved right before the graph is deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Tell all vertices to shout one last time so vertex views 
		# can clean themselves up before the graph disappears.
		for v in vertices.values():
			# Check if valid instance(not been deleted yet)
			if is_instance_valid(v):
				v.vanished.emit(v)
					
		vertices.clear()
		
		# We don't need to manually queue_free children.
		# When this Graph (Node2D) is removed from memory, Godot automatically
		# removes all children (vertex_views and edge_views) from the Scene Tree.
