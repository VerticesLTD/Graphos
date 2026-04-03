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


## True when the active create-tool strategy is directed (matches toolbar / new edges).
func is_directed() -> bool:
	return Globals.active_strategy is DirectedStrategy


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

	# Clean up OUTGOING edges first
	# We copy neighbors to an array to safely iterate while the linked list is being modified.
	var neighbors = v.get_outgoing_neighbors()
	for neighbor in neighbors:
		delete_edge(v.id, neighbor.id)

	# Clean up remaining INCOMING edges
	# Because we did Step 1 first, UndirectedStrategy already deleted its incoming twins!
	# This loop safely sweeps up ONLY the one-way Directed arrows that are left pointing at us.
	for e in get_incoming_edges(v):
		delete_edge(e.src.id, v.id)

	# 3. Recycle ID and remove from graph
	free_ids.append(v.id)
	free_ids.sort() # Ensure the next ID taken is the lowest
	
	v.vanished.emit(v) # View hears this and deletes itself
	vertices.erase(v.id)


## Adds an edge between two existing vertices via the current strategy.
## @param target_strategy: The tool/strategy attempting to make this connection.
## @param shout: If false, creates data-only edges for imposters.
func add_edge(src_id: int, dst_id: int, weight: float, target_strategy: ConnectionStrategy, is_weighted: bool, shout: bool = true) -> void:
	# Optional: Allow self loops
	if src_id == dst_id: 
		if shout: Notify.show_error("Self-loops are not allowed.")
		return 
		
	# If the edge is already there, do nothing.
	if has_edge(src_id, dst_id): 
		return 

	var v_src = vertices.get(src_id)
	var v_dst = vertices.get(dst_id)
	
	if not v_src or not v_dst: return

	# Validate only strategy-level hard conflicts (duplicate/invalid pair rules).
	# Mixed directed/undirected and weighted/unweighted are now allowed at edit/create time.
	var specific_error = target_strategy.get_connection_error(self, v_src, v_dst)
	if specific_error != "":
		if shout:
			Notify.show_error(specific_error)
		return

	# --- ALL CLEAR ---
	target_strategy.add_edge(self, v_src, v_dst, weight, is_weighted, shout)
				
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
	
## Returns all edges in the graph that point TO the given vertex.
## Useful for directed graph operations without complex data structures.
func get_incoming_edges(target: Vertex) -> Array[Edge]:
	var incoming: Array[Edge] = []
	for v in vertices.values():
		var e = v.edges
		while e:
			if e.dst == target:
				incoming.append(e)
			e = e.next
	return incoming
		
		
## Returns the shared strategy of the vertex.
## Returns EmptyStrategy if the vertex has 0 edges.
## Returns ErrorStrategy if mixed types are found.
func get_vertex_strategy(v: Vertex) -> ConnectionStrategy:
	var shared_strategy: ConnectionStrategy = null
	
	# Check OUTGOING edges first 
	var outgoing = v.get_outgoing_edges()
	for e in outgoing:
		if not e or not e.strategy: continue
			
		if shared_strategy == null:
			shared_strategy = e.strategy
		elif shared_strategy.get_script() != e.strategy.get_script():
			return ErrorStrategy.new()
	
	# Check if the strategy doesn't need incoming edges
	if shared_strategy != null and not shared_strategy.requires_incoming_capture():
		return shared_strategy

	# Check INCOMING edges, runs if Directed, or if vertex was empty
	var incoming = get_incoming_edges(v)
	for e in incoming:
		if not e or not e.strategy: continue
			
		if shared_strategy == null:
			shared_strategy = e.strategy
		elif shared_strategy.get_script() != e.strategy.get_script():
			return ErrorStrategy.new()

	# Final Verdict
	if shared_strategy == null:
		return EmptyStrategy.new()
		
	return shared_strategy
	
## Asks the vertex if it currently holds weighted or unweighted edges.
func get_vertex_weight_state(v: Vertex) -> Globals.WeightState:
	var shared_weight = null
	
	# 1. Check what's going out
	for e in v.get_outgoing_edges():
		if not e: continue
		if shared_weight == null:
			shared_weight = e.is_weighted
		elif shared_weight != e.is_weighted:
			return Globals.WeightState.CORRUPTED
			
	# 2. Check what's coming in
	for e in get_incoming_edges(v):
		if not e: continue
		if shared_weight == null:
			shared_weight = e.is_weighted
		elif shared_weight != e.is_weighted:
			return Globals.WeightState.CORRUPTED
			
	# 3. Deliver the verdict
	if shared_weight == null:
		return Globals.WeightState.EMPTY
		
	return Globals.WeightState.WEIGHTED if shared_weight else Globals.WeightState.UNWEIGHTED
	
## Validates if a single vertex can accept the target connection strategy.
func _validate_vertex_strategy(v: Vertex, target_strategy: ConnectionStrategy) -> String:
	var strat = get_vertex_strategy(v)
	
	if strat is ErrorStrategy:
		return "Graph Error: This vertex has mixed edge types. Clear its edges to fix it."
		
	if not strat is EmptyStrategy and strat.get_script() != target_strategy.get_script():
		return "Type Clash: You can't mix Directed and Undirected edges."
		
	return ""
	
## Validates if a single vertex can accept the target weight state.
func _validate_vertex_weight(v: Vertex, is_weighted: bool) -> String:
	var weight_state = get_vertex_weight_state(v)
	var target_weight_state = Globals.WeightState.WEIGHTED if is_weighted else Globals.WeightState.UNWEIGHTED
	
	if weight_state == Globals.WeightState.CORRUPTED:
		return "Weight Error: This vertex is confused. It has both weighted and unweighted edges."
		
	if weight_state != Globals.WeightState.EMPTY and weight_state != target_weight_state:
		return "Weight Clash: You can't mix Weighted and Unweighted edges on the same vertex."
		
	return ""
	
## Runs all safety checks on a single vertex.
func _validate_vertex(v: Vertex, target_strategy: ConnectionStrategy, is_weighted: bool) -> String:
	var strat_error = _validate_vertex_strategy(v, target_strategy)
	if strat_error != "": return strat_error
	
	var weight_error = _validate_vertex_weight(v, is_weighted)
	if weight_error != "": return weight_error
	
	return ""
	
## Checks if a new connection breaks any connection rules.
func _validate_connection(v_src: Vertex, v_dst: Vertex, target_strategy: ConnectionStrategy, is_weighted: bool) -> String:
	# Validates vertices against the current global state, 
	# thus, from transitivity, we're gurenteed the conenction is safe. 
	# Check Source
	var src_error = _validate_vertex(v_src, target_strategy, is_weighted)
	if src_error != "": return src_error
	
	# Check Destination
	var dst_error = _validate_vertex(v_dst, target_strategy, is_weighted)
	if dst_error != "": return dst_error

	# Ask the strategy if the connection is legal.
	var specific_error = target_strategy.get_connection_error(self, v_src, v_dst)
	if specific_error != "": return specific_error

	return ""
		
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
	var imposter_graph = Graph.new()
	
	# Clone the Nodes
	for v in source_vertices:
		var imposter_v = Vertex.new(v.id, v.color, v.distance, v.key, v.pos, true)
		imposter_graph.vertices[v.id] = imposter_v

	# Fast lookup for selection
	var selection_ids = {}
	for v in source_vertices: selection_ids[v.id] = true

	# Clone the edges 
	for v in source_vertices:
		var e = v.edges
		while e:
			# Only clone if the destination is also selected
			if selection_ids.has(e.dst.id):
				# CRITICAL: Only add if the imposter doesn't have it yet. Prevents duplications.
				if not imposter_graph.has_edge(e.src.id, e.dst.id):
					imposter_graph.add_edge(
						e.src.id, 
						e.dst.id, 
						e.weight, 
						e.strategy, # Use the ACTUAL strategy of this edge
						e.is_weighted, 
						false # silent
					)
			e = e.next
	
	return imposter_graph
		

## Scans the entire graph. Returns the common strategy if all match types.
## Returns null if the graph contains a mix (e.g., some Directed, some Undirected).
func get_graph_dominant_strategy() -> ConnectionStrategy:
	var all_edges = _get_unique_edges()
	if all_edges.is_empty(): return null
	
	var first_strat_script = all_edges[0].strategy.get_script()
	
	for e in all_edges:
		if e.strategy.get_script() != first_strat_script:
			return null # Mixed strategies 
			
	return all_edges[0].strategy
	

## Returns "weighted" if all edges are weighted, "unweighted" if all are unweighted.
## Returns null if the graph contains a mix (Inconsistent).
func get_graph_weight_state() -> Variant:
	var all_edges = _get_unique_edges()
	
	# An empty graph, defaults to unweighted
	if all_edges.is_empty(): 
		return "unweighted" 
	
	var first_is_weighted = all_edges[0].is_weighted
	
	for e in all_edges:
		if e.is_weighted != first_is_weighted:
			return null # MIXED
			
	return "weighted" if first_is_weighted else "unweighted"


## Returns true if the graph is one weakly connected component (for undirected graphs, usual connectivity).
## Traverses outgoing and incoming edges so directed graphs are checked correctly.
func is_weakly_connected() -> bool:
	var n: int = vertices.size()
	if n <= 1:
		return true
	var start: Vertex = null
	for v: Vertex in vertices.values():
		start = v
		break
	if start == null:
		return true
	var visited: Dictionary = {}
	var queue: Array[Vertex] = [start]
	visited[start.id] = true
	var qi := 0
	while qi < queue.size():
		var u: Vertex = queue[qi]
		qi += 1
		var e: Edge = u.edges
		while e:
			var v: Vertex = e.dst
			if vertices.has(v.id) and not visited.has(v.id):
				visited[v.id] = true
				queue.append(v)
			e = e.next
		for inc: Edge in get_incoming_edges(u):
			var w: Vertex = inc.src
			if vertices.has(w.id) and not visited.has(w.id):
				visited[w.id] = true
				queue.append(w)
	return visited.size() == n


## Helper: Returns a flat list of logical edges (one entry per directed arc or undirected pair).
## Important: `Array.has(edge)` is O(n) per check — on dense graphs that becomes ~O(E²).
## Undirected edges are stored as two Edge objects (A→B and B→A); we key by sorted endpoints
## so strategy/weight checks see each undirected connection once (same idea as `UndirectedStrategy.clone_edges`).
func _get_unique_edges() -> Array[Edge]:
	var list: Array[Edge] = []
	var seen: Dictionary = {}
	for v in vertices.values():
		var e: Edge = v.edges
		while e:
			var key: String
			if e.strategy is UndirectedStrategy:
				var a: int = mini(e.src.id, e.dst.id)
				var b: int = maxi(e.src.id, e.dst.id)
				key = "U:%d:%d" % [a, b]
			else:
				key = "D:%d:%d" % [e.src.id, e.dst.id]
			if not seen.has(key):
				seen[key] = true
				list.append(e)
			e = e.next
	return list
	
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
