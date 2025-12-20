## Represents an undirected graph using adjacency lists.
## Each undirected edge is stored internally as two directed edges.
## The edge counter tracks logical undirected edges.
class_name UndirectedGraph
extends Node2D

## Radius of circle drawn for each vertex
const VERTEX_RADIUS = 20.0

## Edge appearance
const EDGE_COLOR = Color.RED
const EDGE_WIDTH = 10.0

## Dictionary[int -> Vertex]
## Godot does not support generic typing for dictionaries.
var vertices: Dictionary = {}

## Total number of vertices in the graph.
var num_vertices: int = 0

## Total number of undirected edges in the graph.
var num_edges: int = 0

## Used to remember the first vertex of 2 vertices to link an edge between
var vertex_to_link:int = Globals.NOT_FOUND

func _ready() -> void:
	# Requesting handler to notify us about mouse clicks
	InputHandler.subscribe_to_intention(
			InputHandler.INTENTION_TYPE.MOUSE_CLICK,
			self
		)

## Removes all vertices and edges from the graph.
func clear() -> void:
	vertices.clear()
	num_vertices = 0
	num_edges = 0

## Adds a vertex to the graph if it does not already exist.
## @param id    Unique vertex identifier.
## @param x     Optional x-coordinate.
## @param y     Optional y-coordinate.
## @param color Optional color.
func add_vertex(id: int, pos:Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> void:
	# TODO: Having the id as an arguments exposes potential problems.
	# id should be inside `Globals`, and the responsibility to increment the id should
	# be under the function doing the adding, not the caller.
	if not vertices.has(id):
		var v: Vertex = Vertex.new(id, color, Vertex.INF, Vertex.INF, pos)
		vertices[id] = v
		num_vertices += 1

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
	
## Adds an undirected edge between two existing vertices.
## @param src_id Source vertex ID.
## @param dst_id Destination vertex ID.
## @param weight Edge weight.
func add_edge(src_id: int, dst_id: int, weight: int = 1) -> void:
	var src: Vertex = vertices[src_id]
	var dst: Vertex = vertices[dst_id]

	var before: int = src.degree
	src.connect_vertices(dst, weight)
	var after: int = src.degree

	if after > before:
		dst.connect_vertices(src, weight)
		num_edges += 1

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


## Removes a vertex and all incident edges.
func delete_vertex(id: int) -> void:
	if not vertices.has(id):
		return

	var victim: Vertex = vertices[id]

	var e: Edge = victim.edges
	var removed: int = 0
	while e:
		removed += 1
		e = e.next

	for v: Vertex in vertices.values():
		if v != victim:
			v.delete_edge(victim)

	num_edges -= removed
	num_vertices -= 1
	vertices.erase(id)

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

## Iterates over vertices to check if position is colliding with one
## of them.
func get_vertex_collision(pos: Vector2) -> int:
	for v: Vertex in vertices.values():
		if v.pos.distance_to(pos) <= VERTEX_RADIUS:
			return v.id
	return Globals.NOT_FOUND

## This function is executed by InputHandler for the subscribed intentions.
func execute_intention(intention:InputHandler.Intention) -> void:
	var event:InputEvent = intention.event

	# Currently only executing mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var pos:Vector2 = get_global_mouse_position()
			_handle_left_click(pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			var pos:Vector2 = get_global_mouse_position()
			_handle_right_click(pos)


## Handles user left click.
## Creates a vertex at posistion.
func _handle_left_click(pos:Vector2) -> void:
	self.add_vertex(Globals.vertex_id,pos,Color.GREEN)
	Globals.vertex_id += 1
	queue_redraw()

## Handles user right click.
## If user clicked on a vertex, it's ID is remembered.
## When 2 different vertices have been clicked, add an edge between them.
func _handle_right_click(pos: Vector2) -> void:
	var id = get_vertex_collision(pos)
	if id == Globals.NOT_FOUND:
		return
	GLogger.debug("Rightclick on ID: " + str(id),"GRAPH_RIGHT_CLICK")

	if vertex_to_link == Globals.NOT_FOUND:
		vertex_to_link = id
		GLogger.debug("First node to link remembered","GRAPH_RIGHT_CLICK")
		return

	if vertex_to_link == id:
		GLogger.debug("Clicked twice on the same vertex. Skipping.","GRAPH_RIGHT_CLICK")

	self.add_edge(vertex_to_link,id)
	vertex_to_link = Globals.NOT_FOUND

	queue_redraw()
	
## To draw the graph, we first iterate over all edges and draw them using `draw_line`.
## Then we draw vertices using `draw_circle`. Doing edges first allows the vertices to
## appear on top of edges.
func _draw() -> void:
	for v:Vertex in vertices.values():
		var e = v.edges

		while e:
			if e.src.id < e.dst.id:
				draw_line(e.src.pos,e.dst.pos,e.color,EDGE_WIDTH)
			e = e.next

	for v:Vertex in vertices.values():
		draw_circle(v.pos,VERTEX_RADIUS,v.color,true,-1.0,true)
