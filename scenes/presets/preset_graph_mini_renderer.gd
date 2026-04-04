## Renders a detached preset Graph inside a SubViewport (vertex colors from data; edges use Globals.EDGE_COLOR).
extends Node2D
class_name PresetGraphMiniRenderer

## Filled behind the graph; use Color(0,0,0,0) to skip drawing (e.g. welcome overlay).
@export var background_color: Color = Color.WHITE

var _graph: Graph


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _graph:
		_graph.queue_free()
		_graph = null


func set_graph_from_json_path(json_path: String) -> void:
	if _graph:
		_graph.queue_free()
		_graph = null
	_graph = GraphPresetIO.load_preset_from_file(json_path)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport() as SubViewport
	var vw: float = float(vp.size.x) if vp else 128.0
	var vh: float = float(vp.size.y) if vp else 88.0
	if background_color.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, Vector2(vw, vh)), background_color)

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

	var pad := 8.0
	var bw := maxf(bb.size.x, 1.0)
	var bh := maxf(bb.size.y, 1.0)
	var sx := (vw - 2.0 * pad) / bw
	var sy := (vh - 2.0 * pad) / bh
	var sc := minf(sx, sy)
	var ctr := bb.get_center()
	var origin := Vector2(vw * 0.5, vh * 0.5)

	# Smaller vertices let edge structure show through; slightly thicker edges compensate.
	var lw := clampf(Globals.EDGE_WIDTH * 0.18, 1.4, 2.8)
	var rr := clampf(Globals.VERTEX_RADIUS * 0.17, 2.2, 4.5)

	for v: Vertex in _graph.vertices.values():
		var e: Edge = v.edges
		while e:
			if _graph.vertices.has(e.dst.id) and e.strategy.should_paste_edge(v.id, e.dst.id):
				var a: Vector2 = _map_pt(pts[v.id], origin, ctr, sc)
				var b: Vector2 = _map_pt(pts[e.dst.id], origin, ctr, sc)
				var ec: Color = Globals.EDGE_COLOR
				draw_line(a, b, ec, lw, true)
				if e.strategy is DirectedStrategy:
					_draw_arrow_head(a, b, ec, lw)
			e = e.next

	for v: Vertex in _graph.vertices.values():
		var c: Vector2 = _map_pt(pts[v.id], origin, ctr, sc)
		draw_circle(c, rr + 1.4, Color(1, 1, 1, 0.95), true, -1.0, true)
		draw_circle(c, rr, v.color, true, -1.0, true)


func _draw_arrow_head(from: Vector2, to: Vector2, col: Color, _lw: float) -> void:
	var dir := (to - from)
	if dir.length_squared() < 4.0:
		return
	dir = dir.normalized()
	var tip := to - dir * 5.5
	var n := dir.orthogonal() * 3.8
	var poly := PackedVector2Array([to, tip + n, tip - n])
	draw_colored_polygon(poly, col)


func _map_pt(p: Vector2, origin: Vector2, ctr: Vector2, sc: float) -> Vector2:
	return origin + (p - ctr) * sc
