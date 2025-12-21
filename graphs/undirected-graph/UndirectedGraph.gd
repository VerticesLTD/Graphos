## Represents an undirected graph using adjacency lists.
## The Graph acts as the "Stage Manager": it creates Brains (Data) 
## and Puppets (Scenes) and connects them.
extends Node2D
class_name UndirectedGraph

# We load our "Blueprints" (Scenes) here
const VERTEX_VIEW_SCENE = preload("res://ui/vertex/VertexView.tscn")
const EDGE_VIEW_SCENE = preload("res://ui/edge/EdgeView.tscn")


## Dictionary[int -> Vertex]
var vertices: Dictionary = {}

## Edge appearance
const EDGE_COLOR = Color.RED
const EDGE_WIDTH = 10.0

## Metadata counters
var num_vertices: int = 0
var num_edges: int = 0

## Internal counter to ensure every vertex gets a unique, incremental ID
var _next_vertex_id: int = 0


func _ready() -> void:
	#Subscribe to global mouse clicks via our InputHandler
	InputHandler.subscribe_to_intention(
			InputHandler.INTENTION_TYPE.MOUSE_CLICK,
			self
		)

## ------------------------------------------------------------------------------
## SIGNAL REACTION: The Factory Logic
## ------------------------------------------------------------------------------

## This runs whenever a vertex emits 'edge_added'
func _on_edge_added(new_edge: Edge) -> void:
	# To draw the edge only once, add just if id.src is smaller
	if new_edge.src.id > new_edge.dst.id:
		return

	# Create the visual Body
	var line = EDGE_VIEW_SCENE.instantiate()
	line.data = new_edge

	# Add to scene and ensure it's drawn BEHIND the vertices
	add_child(line)
	move_child(line, 0)	
	
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
## GRAPH OPERATIONS (The Brain Factory)
## ------------------------------------------------------------------------------
	
## Adds a vertex to the graph if it does not already exist.
## Connects the scenes and data connected to the vertex.
## Returns the vertex's id.
## @param id    Unique vertex identifier.
## @param x     Optional x-coordinate.
## @param y     Optional y-coordinate.
## @param color Optional color.
func add_vertex(pos: Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> int:
	var id = _next_vertex_id # Get the next available ID internally
	_next_vertex_id += 1 # increment
	
	# 1. Create the Brain (Data)
	var v: Vertex = Vertex.new(id, color, Vertex.INF, Vertex.INF, pos)
	vertices[id] = v
	num_vertices += 1

	# 2. Create the Body (The Scene)
	var view = VERTEX_VIEW_SCENE.instantiate()

	# 3. THE HANDSHAKE, link Vertex to VertexView
	view.data = v 

	# 4. Show it on screen
	add_child(view)
	
	# 5: Tell the graph to listen for when we add an edge
	v.edge_added.connect(_on_edge_added)
	
	# 6: Tell the graph to listen for when we delete an edge
	v.edge_removed.connect(_on_edge_removed)
	
	return id


## Adds an undirected edge between two existing vertices. 
## Connects the vertices
## @param src_id Source vertex ID.
## @param dst_id Destination vertex ID.
## @param weight Edge weight.
func add_edge(src_id: int, dst_id: int, weight: int = 1) -> void:
	if src_id == dst_id or has_edge(src_id, dst_id):
		return

	var src: Vertex = vertices[src_id]
	var dst: Vertex = vertices[dst_id]

	## Connecting the brains
	## This automatically triggers the 'edge_added' signal below.
	src.connect_vertices(dst, weight)
	dst.connect_vertices(src, weight)
	
	
## Removes a vertex and all incident edges.
func delete_vertex(id: int) -> void:
	if not vertices.has(id):
		return
	
	var victim: Vertex = vertices[id]

	# Signals to remove the visuals of the vertex
	victim.vanished.emit()

	var num_removed_edges = victim.degree
	
	# Delete edges next to the vertex
	for v: Vertex in vertices.values():
		if v != victim:
			v.delete_edge(victim)
			
	# Update the graph's metadata
	num_edges -= num_removed_edges
	num_vertices -= 1
	vertices.erase(id)	
		
			
## Removes all vertices and edges from the graph.
func clear() -> void:
	vertices.clear()
	num_vertices = 0
	num_edges = 0

		
## Returns the vertex with the given ID.
## IMPORTANT:
## This function intentionally has NO return type annotation.
## Reason:
##   - It may return `null` if the vertex does not exist.
##   - Godot does not support nullable return types (e.g. Vertex?).
## Callers MUST explicitly handle the null case.
func get_vertex(id: int):
	return vertices.get(id)

## Returns the edge connecting u and v, or null if none exists.
func get_edge(u: Vertex, v: Vertex) -> Edge:
	var e = u.edges
	while e:
		if e.dst == v:
			return e
		e = e.next
	return null


## Removes an undirected edge between two vertices.
func delete_edge(src_id: int, dst_id: int) -> void:
	if not vertices.has(src_id) or not vertices.has(dst_id):
		return

	var src_node: Vertex = vertices[src_id]
	var dst_node: Vertex = vertices[dst_id]

	# To avoid duplicate deletion, we delete visually only edge with the lower id.
	if src_id < dst_id:
		src_node.delete_edge(dst_node, true) # This one shouts
		dst_node.delete_edge(src_node, false) # This one is silent
	else:
		dst_node.delete_edge(src_node, true) # This one shouts
		src_node.delete_edge(dst_node, false) # This one is silent
		
	num_edges -= 1 # Decrease num edges in the graph


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

## Iterates over vertices to check if position is colliding with one of them.
func get_vertex_collision(pos: Vector2) -> int:
	for v: Vertex in vertices.values():
		if v.pos.distance_to(pos) <= Globals.VERTEX_RADIUS:
			return v.id
	return Globals.NOT_FOUND



## NOTE: _draw() has been deleted.
## The Node2D children (VertexView/EdgeView) handle their own rendering.
## GraphController now handles the inputs.
