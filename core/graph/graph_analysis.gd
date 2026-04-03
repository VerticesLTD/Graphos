## Read-only analysis helpers for Graph.
##
## Kept separate from Graph intentionally — Graph owns mutation and indexing,
## while this file answers "what does this graph look like right now?" questions.
## None of these functions modify any state.
##
## Usage (from graph.gd):
##   GRAPH_ANALYSIS_SCRIPT.get_vertex_strategy(self, v)
##
## Note: no class_name here to avoid a circular-dependency issue.
## (this file references Graph methods, and graph.gd preloads this file)


## Returns the connection strategy shared by all edges on a vertex.
## Returns EmptyStrategy if the vertex has no edges.
## Returns ErrorStrategy if directed and undirected edges are mixed (shouldn't happen normally).
static func get_vertex_strategy(graph: Node2D, v: Vertex) -> ConnectionStrategy:
	var shared_strategy: ConnectionStrategy = null

	# Check outgoing edges first — for undirected graphs this is enough
	# because every undirected edge stores a mirror arc on both ends.
	for e in v.get_outgoing_edges():
		if not e or not e.strategy:
			continue
		if shared_strategy == null:
			shared_strategy = e.strategy
		elif shared_strategy.get_script() != e.strategy.get_script():
			return ErrorStrategy.new()

	# Directed edges don't mirror, so we skip the incoming scan only when
	# we already found an undirected strategy (it doesn't need incoming data).
	if shared_strategy != null and not shared_strategy.requires_incoming_capture():
		return shared_strategy

	for e in graph.get_incoming_edges(v):
		if not e or not e.strategy:
			continue
		if shared_strategy == null:
			shared_strategy = e.strategy
		elif shared_strategy.get_script() != e.strategy.get_script():
			return ErrorStrategy.new()

	return shared_strategy if shared_strategy != null else EmptyStrategy.new()


## Returns whether all edges on this vertex are weighted, unweighted, or mixed.
static func get_vertex_weight_state(graph: Node2D, v: Vertex) -> Globals.WeightState:
	var shared_weight = null

	for e in v.get_outgoing_edges():
		if not e:
			continue
		if shared_weight == null:
			shared_weight = e.is_weighted
		elif shared_weight != e.is_weighted:
			return Globals.WeightState.CORRUPTED

	for e in graph.get_incoming_edges(v):
		if not e:
			continue
		if shared_weight == null:
			shared_weight = e.is_weighted
		elif shared_weight != e.is_weighted:
			return Globals.WeightState.CORRUPTED

	if shared_weight == null:
		return Globals.WeightState.EMPTY
	return Globals.WeightState.WEIGHTED if shared_weight else Globals.WeightState.UNWEIGHTED


## Returns the shared strategy for edges WITHIN a selection, or null if mixed.
static func get_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	var shared_strategy: ConnectionStrategy = null
	# Fast set so we only check edges where both endpoints are selected.
	var subset_ids: Dictionary = {}
	for v in source_vertices:
		subset_ids[v.id] = true

	for v in source_vertices:
		var e = v.edges
		while e:
			if subset_ids.has(e.dst.id):
				if shared_strategy == null:
					shared_strategy = e.strategy
				elif e.strategy != shared_strategy:
					return null  # Mixed types found.
			e = e.next
	return shared_strategy


## Like get_selection_strategy, but shows a user-visible error if the selection is mixed.
static func get_valid_selection_strategy(source_vertices: Array[Vertex]) -> ConnectionStrategy:
	var strategy = get_selection_strategy(source_vertices)
	if strategy == null:
		Notify.show_error("Mixed Graph Error: Please select edges of only one type (Directed OR Undirected).")
	return strategy


## Returns the dominant strategy if every edge in the graph is the same type.
## Returns null if there's a mix of directed and undirected edges.
static func get_graph_dominant_strategy(graph: Node2D) -> ConnectionStrategy:
	var all_edges = graph._get_unique_edges()
	if all_edges.is_empty():
		return null
	var first_strat_script = all_edges[0].strategy.get_script()
	for e in all_edges:
		if e.strategy.get_script() != first_strat_script:
			return null
	return all_edges[0].strategy


## Returns "weighted", "unweighted", or null for a mixed graph.
## An empty graph defaults to "unweighted".
static func get_graph_weight_state(graph: Node2D) -> Variant:
	var all_edges = graph._get_unique_edges()
	if all_edges.is_empty():
		return "unweighted"
	var first_is_weighted = all_edges[0].is_weighted
	for e in all_edges:
		if e.is_weighted != first_is_weighted:
			return null
	return "weighted" if first_is_weighted else "unweighted"


## Returns true if the graph is one weakly-connected component.
## "Weakly" means we ignore direction — both directed and undirected graphs pass
## as long as every vertex is reachable from every other vertex (ignoring arrows).
static func is_weakly_connected(graph: Node2D) -> bool:
	var n: int = graph.vertices.size()
	if n <= 1:
		return true

	var start: Vertex = null
	for v: Vertex in graph.vertices.values():
		start = v
		break
	if start == null:
		return true

	# BFS over both outgoing and incoming edges so direction doesn't block traversal.
	var visited: Dictionary = {}
	var queue: Array[Vertex] = [start]
	visited[start.id] = true
	var qi := 0
	while qi < queue.size():
		var u: Vertex = queue[qi]
		qi += 1

		var e: Edge = u.edges
		while e:
			var dst: Vertex = e.dst
			if graph.vertices.has(dst.id) and not visited.has(dst.id):
				visited[dst.id] = true
				queue.append(dst)
			e = e.next

		for inc: Edge in graph.get_incoming_edges(u):
			var src: Vertex = inc.src
			if graph.vertices.has(src.id) and not visited.has(src.id):
				visited[src.id] = true
				queue.append(src)

	return visited.size() == n
