# Headless micro-benchmarks for Graphos hot paths (data + graph helpers).
#
# Run (autoloads load correctly when using a scene):
#   godot --path . --headless res://scenes/dev/profile_benchmark.tscn
#
# Safe to delete `scripts/dev/` + `scenes/dev/` benchmark files if unwanted.

extends Node


func _ready() -> void:
	print("\n=== Graphos profile_benchmark (headless scene) ===\n")

	var g := Graph.new()
	add_child(g)
	await get_tree().process_frame

	var n_dense := 100
	print("Building dense directed graph: V=%d, E≈%d (add_vertex creates views) …" % [n_dense, n_dense * (n_dense - 1)])
	var t_build_begin := Time.get_ticks_usec()
	_build_dense_directed_no_ui(g, n_dense)
	var t_build_end := Time.get_ticks_usec()
	print("  build_wall_ms: %.2f" % ((t_build_end - t_build_begin) / 1000.0))

	_print_timing("get_graph_dominant_strategy()", func(): g.get_graph_dominant_strategy())
	_print_timing("get_graph_weight_state()", func(): g.get_graph_weight_state())
	_print_timing("is_weakly_connected()", func(): g.is_weakly_connected())
	_print_timing("get_edge forward+reverse × E", func(): _bench_get_edge_pairs(g))
	_print_timing("_walk_unique_edges (canonical keys)", func(): _walk_unique_edges_canonical_keys(g))
	_print_timing("Dijkstra-style _pop_min × V", func(): _bench_linear_pop_min(n_dense))

	_bench_selection_membership(n_dense)

	print("\n--- Interpretation (what to change if these dominate in-editor) ---")
	print("  • Large ms on get_graph_* → should be rare now (Graph._get_unique_edges uses dict + canonical keys).")
	print("  • Large ms on is_weakly_connected → avoid get_incoming_edges full scan per vertex (reverse adjacency).")
	print("  • Large ms on get_edge × E → popup direction checks should use cached edge facts in one pass.")
	print("  • Large ms on _pop_min → priority queue for Dijkstra/Prim frontier.")
	print("  • Large gap Array `in` vs dict → selection + AnimationManager membership.")
	print("  • This scene does not measure UIEdgeView.refresh(); use Editor Profiler while hovering/moving selection.")
	print("\n=== done ===\n")

	# Let queued frees run before quit (cleaner headless shutdown / fewer leak warnings).
	g.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _print_timing(label: String, callable: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	callable.call()
	var t1 := Time.get_ticks_usec()
	print("  %-42s %8.2f ms" % [label, (t1 - t0) / 1000.0])


func _build_dense_directed_no_ui(g: Graph, n: int) -> void:
	var strat := DirectedStrategy.new()
	for _i in n:
		g.add_vertex(Vector2.ZERO)
	for i in n:
		for j in n:
			if i == j:
				continue
			g.add_edge(i, j, 1.0, strat, false, false)


func _collect_directed_edges(g: Graph) -> Array[Edge]:
	var out: Array[Edge] = []
	for v: Vertex in g.vertices.values():
		var e: Edge = v.edges
		while e:
			out.append(e)
			e = e.next
	return out


func _bench_get_edge_pairs(g: Graph) -> void:
	var edges := _collect_directed_edges(g)
	for e in edges:
		var _f: Edge = g.get_edge(e.src, e.dst)
		var _r: Edge = g.get_edge(e.dst, e.src)


## Mirrors `Graph._get_unique_edges` traversal cost (O(E) with dict), not the old `Array.has` path.
func _walk_unique_edges_canonical_keys(g: Graph) -> void:
	var list: Array[Edge] = []
	var seen := {}
	for v in g.vertices.values():
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


func _bench_linear_pop_min(frontier_cap: int) -> void:
	var verts: Array[Dictionary] = []
	for i in frontier_cap:
		verts.append({&"id": i, &"key": float(i)})
	var in_frontier := {}
	for v in verts:
		in_frontier[v[&"id"]] = true
	while not verts.is_empty():
		var best_index := 0
		var best_key: float = verts[0][&"key"]
		for ii in range(1, verts.size()):
			var k: float = verts[ii][&"key"]
			if k < best_key:
				best_key = k
				best_index = ii
		var best: Dictionary = verts[best_index]
		verts.remove_at(best_index)
		in_frontier.erase(best[&"id"])


func _bench_selection_membership(vert_count: int) -> void:
	var sel_arr: Array[int] = []
	var sel_dict := {}
	for i in mini(200, vert_count):
		sel_arr.append(i)
		sel_dict[i] = true
	var probe_count := 10_000
	var t0 := Time.get_ticks_usec()
	for _k in probe_count:
		for id in range(vert_count):
			var _hit := id in sel_arr
	var t1 := Time.get_ticks_usec()
	print("  %-42s %8.2f ms  (%d×V Array `in`)" % [
		"selection: `id in Array`", (t1 - t0) / 1000.0, probe_count
	])
	t0 = Time.get_ticks_usec()
	for _k in probe_count:
		for id in range(vert_count):
			var _hit2 := sel_dict.has(id)
	t1 = Time.get_ticks_usec()
	print("  %-42s %8.2f ms  (Dictionary.has)" % [
		"selection: dict.has(id)", (t1 - t0) / 1000.0
	])
