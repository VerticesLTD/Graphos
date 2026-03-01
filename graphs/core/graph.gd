## Represents an undirected graph using adjacency lists.
## The Graph acts as the "Stage Manager": it creates Brains (Data) 
## and Puppets (Scenes) and connects them.
extends Node2D
class_name UndirectedGraph

# We load our "Blueprints" (Scenes) here
const EDGE_VIEW_SCENE = preload("uid://bmti1ysdlhopk")
const VERTEX_VIEW_SCENE = preload("uid://cxt6f2vgtos0c")


## Dictionary[int -> Vertex]
var vertices: Dictionary = {}

var free_ids: Array[int] = []


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
	
	
## This runs whenever a vertex emits 'edge_added'
func _on_edge_added(new_edge: Edge) -> void:
	# IMPORTANT: This runs TWICE. One for the edge data from the src to dst, and once
	# for the opposite direction. Since only one view should be instantiated for every edge,
	# we need to find out which one of the two edges should create the view.

	# Check if destination already has an edge/view to source
	var edge_view: UIEdgeView = null
	var dst_edges = new_edge.dst.edges
	var dst_have_opposite_edge = false
	while dst_edges:
		if dst_edges.dst == new_edge.src:
			dst_have_opposite_edge = true # Dst has an edge pointing at us
			if dst_edges.view != null:
				edge_view = dst_edges.view
			break
		dst_edges = dst_edges.next

	# Destination didn't have a view
	if edge_view == null:
		edge_view = EDGE_VIEW_SCENE.instantiate()
		edge_view.edge_data = new_edge
		add_child(edge_view)

		# Incrementation of edge count only happens when a view is instantiated to ensure accuracy.
		num_edges += 1

		if dst_have_opposite_edge:
			# Injecting the created view as a reference to the other edge.
			dst_edges.view = edge_view

	# Setting the view (new or old) as the view for the new edge
	new_edge.view = edge_view
	move_child(edge_view, 0)	# Draw behind vertices
	

## This runs whenever a vertex emits 'edge_removed'
func _on_edge_removed() -> void:
	# The ONLY place we decrement the global count. After we draw successfuly.
	num_edges -= 1
	
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
	
	# Initial connections happen only here, not in redo/undo
	v.edge_added.connect(_on_edge_added)
	
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

## Adds an undirected edge between two existing vertices. 
## Connects the vertices
## @param src_id Source vertex ID.
## @param dst_id Destination vertex ID.
## @param weight Edge weight.
func add_edge(src_id: int, dst_id: int, weight: int = 1) -> void:
	if src_id == dst_id or has_edge(src_id, dst_id):
		return

	var v_src = vertices.get(src_id)
	var v_dst = vertices.get(dst_id)
	
	if not v_src or not v_dst: return

	# Both vertices "Shout" since `on_edge_added` knows to create only one view
	v_src.connect_vertices(v_dst, weight, true) 
	v_dst.connect_vertices(v_src, weight, true)	

## Adds an edge without triggering any UI signals or spawning EdgeViews.
## Used for imposter graphs and internal calculations.
func add_edge_silently(src_id: int, dst_id: int, weight: int = 1) -> void:
	if src_id == dst_id or has_edge(src_id, dst_id):
		return

	var src: Vertex = vertices.get(src_id)
	var dst: Vertex = vertices.get(dst_id)

	if src and dst:
		# We call the vertex data connection directly
		src.connect_vertices(dst, weight, false)
		dst.connect_vertices(src, weight, false)
		num_edges += 1
			
## ------------------------------------------------------------------------------
## DELETE EDGE
## ------------------------------------------------------------------------------

## Removes an undirected edge between two vertices.
## Ensures that even though data is stored twice, the UI only reacts once.
func delete_edge(src_id: int, dst_id: int) -> void:
	var src_node = vertices.get(src_id)
	var dst_node = vertices.get(dst_id)

	if not src_node or not dst_node:
		return

	var edge_a: Edge = src_node.delete_edge(dst_node)
	var edge_b: Edge = dst_node.delete_edge(src_node)

	# Trigerring graph edge removal logic for one edge (Preserves count)
	_on_edge_removed()
	# Both edges now vanish
	edge_a.vanished.emit()
	edge_b.vanished.emit()

			
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
func create_induced_subgraph_from_vertices(source_vertices: Array[Vertex]) -> UndirectedGraph:
	var imposter_graph = UndirectedGraph.new()
	
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
				imposter_graph.add_edge_silently(v.id, neighbor.id)
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
