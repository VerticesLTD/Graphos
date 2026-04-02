## Loads and saves graph presets as JSON (detached graph data for insert/paste).
##
## Root object:
##   format_version: int (currently 1)
##   vertices: [{ "id": int, "pos": [x, y], "color"?: [r,g,b,a] in 0..1 }]
##   edges: [{
##     "from": int, "to": int,
##     "strategy": "directed" | "undirected",
##     "weighted": bool, "weight"?: float,
##     "color"?: [r,g,b,a]
##   }]
##
## Use dictionary_from_vertices() + dictionary_to_json_string() to export a selection.
extends RefCounted
class_name GraphPresetIO

const FORMAT_VERSION := 1


static func load_preset_from_file(path: String) -> Graph:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GraphPresetIO: empty or missing file: %s" % path)
		return null
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GraphPresetIO: invalid JSON root in %s" % path)
		return null
	return graph_from_dictionary(data)


## Builds a detached imposter Graph (not in scene tree) from a preset dictionary.
static func graph_from_dictionary(data: Dictionary) -> Graph:
	var ver := int(data.get("format_version", FORMAT_VERSION))
	if ver != FORMAT_VERSION:
		push_warning("GraphPresetIO: format_version %d (!= %d), continuing anyway." % [ver, FORMAT_VERSION])

	var raw_vertices = data.get("vertices", [])
	var raw_edges = data.get("edges", [])
	if typeof(raw_vertices) != TYPE_ARRAY or raw_vertices.is_empty():
		push_error("GraphPresetIO: preset needs a non-empty vertices array.")
		return null

	var g := Graph.new()
	for item in raw_vertices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vid := int(item.get("id", -1))
		if vid < 0:
			push_error("GraphPresetIO: vertex missing valid id.")
			g.queue_free()
			return null
		var pos_arr = item.get("pos", [0, 0])
		var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var col := _parse_color(item.get("color", null), Globals.VERTEX_COLOR)
		var v := Vertex.new(vid, col, Globals.INF, Globals.INF, pos, true)
		g.vertices[vid] = v

	if typeof(raw_edges) != TYPE_ARRAY:
		push_error("GraphPresetIO: edges must be an array.")
		g.queue_free()
		return null

	for item in raw_edges:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a := int(item.get("from", -1))
		var b := int(item.get("to", -1))
		var strat: ConnectionStrategy = _strategy_from_string(str(item.get("strategy", "undirected")))
		var weighted := bool(item.get("weighted", false))
		var w := float(item.get("weight", 1.0))
		var ecol := _parse_color(item.get("color", null), Globals.EDGE_COLOR)
		if not g.vertices.has(a) or not g.vertices.has(b):
			push_warning("GraphPresetIO: edge (%d,%d) skips — unknown vertex." % [a, b])
			continue
		# Apply color after add: AddEdgeCommand does this for real graphs; imposter uses connect path.
		g.add_edge(a, b, w, strat, weighted, false)
		var va: Vertex = g.vertices[a]
		var vb: Vertex = g.vertices[b]
		var e1 = g.get_edge(va, vb)
		if e1:
			e1.color = ecol
		var e2 = g.get_edge(vb, va)
		if e2:
			e2.color = ecol

	return g


static func _strategy_from_string(s: String) -> ConnectionStrategy:
	match s.to_lower():
		"directed":
			return DirectedStrategy.new()
		"undirected":
			return UndirectedStrategy.new()
		_:
			push_warning("GraphPresetIO: unknown strategy '%s', using undirected." % s)
			return UndirectedStrategy.new()


static func _parse_color(raw, fallback: Color) -> Color:
	if raw == null:
		return fallback
	if typeof(raw) != TYPE_ARRAY or raw.size() < 3:
		return fallback
	var a := 1.0 if raw.size() < 4 else float(raw[3])
	return Color(float(raw[0]), float(raw[1]), float(raw[2]), a)


## Serializes an induced subgraph into the preset dictionary shape (authoring / future export).
static func dictionary_from_vertices(g: Graph, verts: Array[Vertex]) -> Dictionary:
	var sub: Graph = g.create_induced_subgraph_from_vertices(verts)
	var out_vertices: Array = []
	var out_edges: Array = []

	for v in sub.vertices.values():
		out_vertices.append({
			"id": v.id,
			"pos": [v.pos.x, v.pos.y],
			"color": [v.color.r, v.color.g, v.color.b, v.color.a],
		})

	for v in sub.vertices.values():
		var e: Edge = v.edges
		while e:
			if sub.vertices.has(e.dst.id) and e.strategy.should_paste_edge(v.id, e.dst.id):
				out_edges.append({
					"from": v.id,
					"to": e.dst.id,
					"strategy": "directed" if e.strategy is DirectedStrategy else "undirected",
					"weighted": e.is_weighted,
					"weight": e.weight,
					"color": [e.color.r, e.color.g, e.color.b, e.color.a],
				})
			e = e.next

	sub.queue_free()
	return {"format_version": FORMAT_VERSION, "vertices": out_vertices, "edges": out_edges}


static func dictionary_to_json_string(data: Dictionary, pretty: bool = true) -> String:
	if pretty:
		return JSON.stringify(data, "\t")
	return JSON.stringify(data)
