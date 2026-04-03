## Kruskal minimum spanning tree (or forest if disconnected). DSU with per-component colors.
class_name Kruskal
extends GraphAlgorithm

const COLOR_EDGE_CANDIDATE := Color("f39237") # warm Graphos orange: edge under consideration
const COLOR_EDGE_MST := Color("06d6a0") # mint green: accepted MST edge

func get_requirements() -> Dictionary:
	return {
		"weighted": true,
		"directed": false,
	}

func run(_start_vertex: Vertex) -> Array:
	var mst_weight := 0.0
	var data_updates: Array = []

	verify_initialization()
	assert(_start_vertex == null or _start_vertex.is_imposter, "Algorithm instructed to run on a REAL graph (not imposter)")

	var verts: Array[Vertex] = []
	for v: Vertex in imposter_graph.vertices.values():
		verts.append(v)
	verts.sort_custom(func(a: Vertex, b: Vertex) -> bool: return a.id < b.id)

	var n: int = verts.size()
	if n == 0:
		var empty: Array = [[], [], []]
		_reset_alg_variables()
		return empty

	var parent: Dictionary = {}
	var rank: Dictionary = {}
	var members: Dictionary = {} # root_id -> Array[Vertex] (imposter)

	for v: Vertex in verts:
		parent[v.id] = v.id
		rank[v.id] = 0
		var init_mem: Array[Vertex] = []
		init_mem.append(v)
		members[v.id] = init_mem

	var distinct := _distinct_colors(n)
	var color_assign: Array[Color] = []
	for i in range(n):
		color_assign.append(distinct[i])
	change_and_log_vertices_per_vertex_colors(verts, color_assign, 1)

	data_updates.append({
		&"E": imposter_graph.num_edges,
		&"V": imposter_graph.num_vertices,
		&"mst_weight": mst_weight,
	})

	var edge_list: Array[Dictionary] = []
	for u: Vertex in imposter_graph.vertices.values():
		for e: Edge in u.get_outgoing_edges():
			var ov: Vertex = e.get_other_vertex(u)
			if u.id < ov.id:
				edge_list.append({"u": u, "v": ov, "edge": e, "w": float(e.weight)})

	edge_list.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(a["w"], b["w"]):
				return a["w"] < b["w"]
			var au: int = a["u"].id
			var bu: int = b["u"].id
			if au != bu:
				return au < bu
			return a["v"].id < b["v"].id
	)

	if edge_list.is_empty():
		timeline.append(null)
		log_pseudo_step(2)
		data_updates.append({&"mst_weight": mst_weight})
	else:
		# Sort (pseudo 2): always a visible edge recolor (lightest edge), not a no-op timeline slot.
		var e0: Edge = edge_list[0]["edge"]
		change_and_log_edge_color(e0, COLOR_EDGE_CANDIDATE, 2)
		data_updates.append({&"mst_weight": mst_weight})

	for ei: int in range(edge_list.size()):
		var item: Dictionary = edge_list[ei]
		var u: Vertex = item["u"]
		var v: Vertex = item["v"]
		var e: Edge = item["edge"]
		var w: float = item["w"]

		if ei > 0:
			change_and_log_edge_color(e, COLOR_EDGE_CANDIDATE, 3)
			data_updates.append({&"mst_weight": mst_weight})
		else:
			# First edge: already VISITING from the sort step; re-apply as pseudo 3 ("for") so this step still runs a Command.
			change_and_log_edge_color(e, COLOR_EDGE_CANDIDATE, 3)
			data_updates.append({&"mst_weight": mst_weight})

		var ru := _find(parent, u.id)
		var rv_root := _find(parent, v.id)

		if ru == rv_root:
			change_and_log_edge_color(e, Globals.EDGE_COLOR, 5)
			data_updates.append({&"mst_weight": mst_weight})
			continue

		# "if find(u) != find(v)" — dim edge before union+MST so this step always changes pixels (not log_pseudo_step(5,true) alone).
		change_and_log_edge_color(e, Globals.EDGE_COLOR, 5)
		data_updates.append({&"mst_weight": mst_weight})

		var lo: int = mini(ru, rv_root)
		var hi: int = maxi(ru, rv_root)
		var winner_color: Color = imposter_graph.get_vertex(lo).color
		var to_paint: Array[Vertex] = []
		for vx: Vertex in members[hi]:
			to_paint.append(vx)

		var real_recolor: Array[Vertex] = []
		for iv: Vertex in to_paint:
			var rvtx: Vertex = real_graph.get_vertex(iv.id)
			if rvtx:
				real_recolor.append(rvtx)

		var ra: int = ru
		var rb: int = rv_root
		if rank[ra] < rank[rb]:
			var t: int = ra
			ra = rb
			rb = t
		parent[rb] = ra
		if rank[ra] == rank[rb]:
			rank[ra] += 1
		members[ra].append_array(members[rb])
		members.erase(rb)

		mst_weight += w

		var real_edge: Edge = _get_real_edge(e)
		if real_edge == null:
			timeline.append(null)
		else:
			timeline.append(KruskalUnionMstCommand.new(real_recolor, winner_color, real_edge, COLOR_EDGE_MST))

		for iv: Vertex in to_paint:
			iv.color = winner_color
		e.color = COLOR_EDGE_MST

		log_pseudo_step(6)
		data_updates.append({&"mst_weight": mst_weight})

	assert(
		timeline.size() == pseudo_steps.size() and pseudo_steps.size() == data_updates.size(),
		"Kruskal mismatch: timeline=%d pseudo=%d data=%d" % [timeline.size(), pseudo_steps.size(), data_updates.size()]
	)

	var result = [timeline.duplicate(), pseudo_steps.duplicate(), data_updates.duplicate(true)]
	_reset_alg_variables()
	return result


func _find(parent: Dictionary, x: int) -> int:
	var p: int = parent[x]
	if p != x:
		parent[x] = _find(parent, p)
	return parent[x]


func _get_real_edge(e: Edge) -> Edge:
	var rs: Vertex = real_graph.get_vertex(e.src.id)
	var rd: Vertex = real_graph.get_vertex(e.dst.id)
	if rs and rd:
		return real_graph.get_edge(rs, rd)
	return null


func _distinct_colors(count: int) -> Array[Color]:
	var out: Array[Color] = []
	if count <= 0:
		return out
	for i in range(count):
		var h: float = float(i) / float(count)
		out.append(Color.from_hsv(h, 0.62, 0.96))
	return out
