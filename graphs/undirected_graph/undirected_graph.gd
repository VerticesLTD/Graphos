## Represents an undirected graph using adjacency lists.
## The Graph acts as the "Stage Manager": it creates Brains (Data) 
## and Puppets (Scenes) and connects them.
extends Node2D
class_name UndirectedGraph

# We load our "Blueprints" (Scenes) here
const VERTEX_VIEW_SCENE = preload("res://ui/vertex/vertex_view.tscn")
const EDGE_VIEW_SCENE = preload("res://ui/edge/edge_view.tscn")


## Dictionary[int -> Vertex]
var vertices: Dictionary = {}

## Edge appearance
const EDGE_COLOR = Color.RED
const EDGE_WIDTH = 10.0

## Metadata counters, num_vertices shouldn't be taken 
## care of manually because we can get it by using size
var num_vertices: int:
	get:
		return vertices.size()
		
var num_edges: int = 0

## Internal counter to ensure every vertex gets a unique, incremental ID
var _next_vertex_id: int = 0

	
## ------------------------------------------------------------------------------
## SIGNAL REACTION, edge/vertex add/remove
## ------------------------------------------------------------------------------

func _on_vertex_added(_v: Vertex) -> void:
	pass


## Function thats called when a vertex is removed.
## @param v The vertex to remove
func _on_vertex_vanished(_v: Vertex) -> void:
	pass
	
	
## This runs whenever a vertex emits 'edge_added'
func _on_edge_added(new_edge: Edge) -> void:
	# SAFETY CHECK: Even if both vertices shouted, we only draw the 
	# edge where the source ID is lower to prevent visual duplicates.
	if new_edge.src.id > new_edge.dst.id:
		return

	# Create the visual Body
	var line: UIEdgeView = EDGE_VIEW_SCENE.instantiate()
	line.edge_data = new_edge

	# Add to scene and ensure it's drawn BEHIND the vertices
	add_child(line)
	move_child(line, 0)	# Draw behind vertices
	
	# The ONLY place we increase the global count. After we draw successfuly.
	num_edges += 1

## This runs whenever a vertex emits 'edge_removed'
func _on_edge_removed(edge_to_remove: Edge) -> void:	
	# Ensures we only run when the id is lower.
	if edge_to_remove.src.id > edge_to_remove.dst.id:
		return
		
	# The ONLY place we decrement the global count. After we draw successfuly.
	num_edges -= 1
	
## ------------------------------------------------------------------------------
## GRAPH OPERATIONS 
## ------------------------------------------------------------------------------
	
	
	
## ------------------------------------------------------------------------------
## ADD VERTEX
## ------------------------------------------------------------------------------

## Adds a vertex to the graph if it does not already exist.
## Connects the scenes and data connected to the vertex.
## Returns the vertex itself.
## @param pos    The position to create the vertex in.
## @param color     The color to create the vertex with.
func add_vertex(pos: Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> Vertex:
	var id = _next_vertex_id # Get the next available ID internally
	_next_vertex_id += 1 # increment id

	# 1. Create the Brain (Data)
	var v: Vertex = Vertex.new(id, color, Vertex.INF, Vertex.INF, pos)
	vertices[id] = v

	# 2. Create the Body (The Scene)
	var view: UIVertexView = VERTEX_VIEW_SCENE.instantiate()

	# 3. THE HANDSHAKE, link Vertex to VertexView
	view.vertex_data = v 

	# 4. Show it on screen
	add_child(view)
	
	# 5. Connect
	v.created.connect(_on_vertex_added)
	v.vanished.connect(_on_vertex_vanished)
	v.edge_added.connect(_on_edge_added)
	v.edge_removed.connect(_on_edge_removed)
	
	# Fire the signal for a new vertex
	v.created.emit(v) 
	return v


## Re-adds an existing vertex object to the graph. 
## Used primarily by the Command system for Redo operations.
## The order here matters! first restore to the graph, then create the view, then reconnect.
func add_vertex_object(v: Vertex) -> void:
	if not v or vertices.has(v.id):
		return

	# 1. Restore to data structure
	vertices[v.id] = v

	# 2. Recreate the visual body
	var view: UIVertexView = VERTEX_VIEW_SCENE.instantiate()
	view.vertex_data = v 
	add_child(view)
	
	# 3. Re-connect the signals FIRST
	v.created.connect(_on_vertex_added)
	v.vanished.connect(_on_vertex_vanished)
	v.edge_added.connect(_on_edge_added)
	v.edge_removed.connect(_on_edge_removed)

	# 4. Emit the creation signal
	v.created.emit(v)
	
	
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

	# Determine who shouts based on ID 
	var first = v_src if src_id < dst_id else v_dst
	var second = v_dst if src_id < dst_id else v_src

	# The lower ID always 'shouts' and creates the UI line
	first.connect_vertices(second, weight, true) 
	second.connect_vertices(first, weight, false)	

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

	var edge_a = src_node.delete_edge(dst_node)
	var edge_b = dst_node.delete_edge(src_node)

	# Choose only the right edge to delete
	var edge_to_signal = edge_a if src_id < dst_id else edge_b

	if edge_to_signal:
		# 1. Manually trigger the graph's counter logic
		_on_edge_removed(edge_to_signal)

		# 2. Tell the EdgeView (Puppet) to delete itself
		edge_to_signal.vanished.emit()

			
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
func get_vertex_collision(pos: Vector2) -> int:
	for v: Vertex in vertices.values():
		if v.pos.distance_to(pos) <= Globals.VERTEX_RADIUS:
			return v.id
	return Globals.NOT_FOUND


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
	
	# Additionally, reset all the colors to white 
	for v in vertices.values():
		v.color = Color.WHITE


## Returns a new sub-graph from given vertices
## This graph is 'Data-Only' and will not appear on screen.
func create_induced_subgraph_from_vertices(source_vertices: Array[Vertex]) -> UndirectedGraph:
	var imposter_graph = UndirectedGraph.new()
	
	# 1. Create the Nodes (The Ghosts)
	for v in source_vertices:
		var imposter_v = Vertex.new(
			v.id, v.color, v.distance, v.key, v.pos, true, v.id
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
