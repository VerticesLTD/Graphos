## Renders a detached preset Graph inside a SubViewport using current Globals theme colors.
extends Node2D
class_name PresetGraphMiniRenderer

var _graph: Graph


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _graph:
		_graph.queue_free()
		_graph = null


func set_graph_from_json_path(json_path: String) -> void:
	if _graph:
		_graph.queue_free()
		_graph = null
	_graph = GraphPresetIO.load_template_from_file(json_path)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport() as SubViewport
	var vw: float = float(vp.size.x) if vp else 128.0
	var vh: float = float(vp.size.y) if vp else 88.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(vw, vh)), Color(0.976, 0.98, 0.996))

	if _graph == null or _graph.vertices.is_empty():
		return

	var pts: Dictionary = {}
	var bb := Rect2()
	var first := true
	for v: Vertex in _graph.vertices.values():
		var p := v.pos
		if first:
			bb = Rect2(p, Vector2.ZERO)
			first = false
		else:
			bb = bb.expand(p)
		pts[v.id] = p

	var pad := 10.0
	var bw := maxf(bb.size.x, 1.0)
	var bh := maxf(bb.size.y, 1.0)
	var sx := (vw - 2.0 * pad) / bw
	var sy := (vh - 2.0 * pad) / bh
	var sc := minf(sx, sy)
	var ctr := bb.get_center()
	var origin := Vector2(vw * 0.5, vh * 0.5)

	var mpt := func(p: Vector2) -> Vector2:
		return origin + (p - ctr) * sc

	var edge_col := Globals.EDGE_COLOR
	var vtx_col := Globals.VERTEX_COLOR
	var lw := clampf(Globals.EDGE_WIDTH * 0.14, 1.1, 2.4)
	var rr := clampf(Globals.VERTEX_RADIUS * 0.24, 3.2, 6.5)

	for v: Vertex in _graph.vertices.values():
		var e: Edge = v.edges
		while e:
			if _graph.vertices.has(e.dst.id) and e.strategy.should_paste_edge(v.id, e.dst.id):
				var a: Vector2 = mpt.call(pts[v.id])
				var b: Vector2 = mpt.call(pts[e.dst.id])
				draw_line(a, b, edge_col, lw)
				if e.strategy is DirectedStrategy:
					_draw_arrow_head(a, b, edge_col, lw)
			e = e.next

	for v: Vertex in _graph.vertices.values():
		var c: Vector2 = mpt.call(pts[v.id])
		draw_circle(c, rr + 1.1, Color(1, 1, 1, 0.92))
		draw_circle(c, rr, vtx_col)


func _draw_arrow_head(from: Vector2, to: Vector2, col: Color, _lw: float) -> void:
	var dir := (to - from)
	if dir.length_squared() < 4.0:
		return
	dir = dir.normalized()
	var tip := to - dir * 5.5
	var n := dir.orthogonal() * 3.8
	var poly := PackedVector2Array([to, tip + n, tip - n])
	draw_colored_polygon(poly, col)
