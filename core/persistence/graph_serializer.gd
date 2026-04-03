## Serializes and deserializes graph structure (vertices + edges) to/from a Dictionary.
##
## This is a pure data layer — no Node/scene dependencies, no I/O.
## Works with both live graphs (spawns UIVertexViews) and imposter graphs.
## Reusable anywhere you need to snapshot or restore a Graph: saves, exports, clipboard, tests.
##
## Output shape:
##   { "next_vertex_id": int, "vertices": [...], "edges": [...] }
extends RefCounted
class_name GraphSerializer


## Serialize all vertices and unique edges of a graph into plain arrays.
static func to_dictionary(graph: Graph) -> Dictionary:
	var out_vertices: Array = []
	var out_edges: Array = []

	for v: Vertex in graph.vertices.values():
		out_vertices.append({
			"id": v.id,
			"pos": [v.pos.x, v.pos.y],
			"color": [v.color.r, v.color.g, v.color.b, v.color.a],
		})

	# Deduplicate undirected twins: each logical edge appears once.
	var seen: Dictionary = {}
	for v: Vertex in graph.vertices.values():
		var e: Edge = v.edges
		while e:
			var key: String
			if e.strategy is UndirectedStrategy:
				key = "U:%d:%d" % [mini(e.src.id, e.dst.id), maxi(e.src.id, e.dst.id)]
			else:
				key = "D:%d:%d" % [e.src.id, e.dst.id]
			if not seen.has(key):
				seen[key] = true
				out_edges.append({
					"from": e.src.id,
					"to": e.dst.id,
					"strategy": "directed" if e.strategy is DirectedStrategy else "undirected",
					"weighted": e.is_weighted,
					"weight": e.weight,
					"color": [e.color.r, e.color.g, e.color.b, e.color.a],
				})
			e = e.next

	return {
		"next_vertex_id": graph._next_vertex_id,
		"vertices": out_vertices,
		"edges": out_edges,
	}


## Load graph data into a live (non-imposter) graph, clearing its existing state first.
## Vertices are restored with their IDs and spawn UI views.
## Returns true on success.
static func from_dictionary(data: Dictionary, graph: Graph) -> bool:
	var raw_vertices = data.get("vertices", [])
	var raw_edges = data.get("edges", [])

	if typeof(raw_vertices) != TYPE_ARRAY:
		push_error("GraphSerializer: 'vertices' must be an array.")
		return false

	graph.clear()

	for item in raw_vertices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vid := int(item.get("id", -1))
		if vid < 0:
			push_error("GraphSerializer: vertex missing valid id — skipped.")
			continue
		var pos_arr = item.get("pos", [0.0, 0.0])
		var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var col := _parse_color(item.get("color", null), Globals.VERTEX_COLOR)
		# is_imposter = false so UIVertexView gets spawned for each vertex.
		var v := Vertex.new(vid, col, Globals.INF, Globals.INF, pos, false)
		graph.restore_vertex(v)

	# Honour the saved ID watermark so future vertices don't collide with loaded ones.
	var saved_next_id := int(data.get("next_vertex_id", graph._next_vertex_id))
	graph._next_vertex_id = maxi(graph._next_vertex_id, saved_next_id)

	# Rebuild the free-ID pool: every ID below the watermark that isn't occupied.
	graph.free_ids.clear()
	for id in range(graph._next_vertex_id):
		if not graph.vertices.has(id):
			graph.free_ids.append(id)

	if typeof(raw_edges) == TYPE_ARRAY:
		for item in raw_edges:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var a := int(item.get("from", -1))
			var b := int(item.get("to", -1))
			if not graph.vertices.has(a) or not graph.vertices.has(b):
				push_warning("GraphSerializer: edge (%d→%d) skipped — unknown vertex." % [a, b])
				continue
			var strat: ConnectionStrategy = _strategy_from_string(str(item.get("strategy", "undirected")))
			var weighted := bool(item.get("weighted", false))
			var w := float(item.get("weight", 1.0))
			var ecol := _parse_color(item.get("color", null), Globals.EDGE_COLOR)
			graph.add_edge(a, b, w, strat, weighted, false)
			# Restore color on both arc directions (undirected = two arcs).
			var va: Vertex = graph.vertices[a]
			var vb: Vertex = graph.vertices[b]
			var e1 = graph.get_edge(va, vb)
			if e1:
				e1.color = ecol
			var e2 = graph.get_edge(vb, va)
			if e2:
				e2.color = ecol

	return true


# --- Helpers ---

static func _strategy_from_string(s: String) -> ConnectionStrategy:
	match s.to_lower():
		"directed":
			return DirectedStrategy.new()
		_:
			return UndirectedStrategy.new()


static func _parse_color(raw: Variant, fallback: Color) -> Color:
	if raw == null or typeof(raw) != TYPE_ARRAY or raw.size() < 3:
		return fallback
	var a := 1.0 if raw.size() < 4 else float(raw[3])
	return Color(float(raw[0]), float(raw[1]), float(raw[2]), a)
