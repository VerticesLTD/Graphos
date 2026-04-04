extends Node2D
## Preview for Ctrl+click edge chains in Create mode: stroke in _draw(), arrow + optional placement disk as children.
class_name GhostEdgePreview

const _PHYS_CTRL_R := 4194328  ## Right Ctrl physical keycode (Input map keycode)
const LINE_ALPHA := 0.42
const GHOST_DISK_ALPHA := 0.22
## Placement hint only — smaller than a real vertex so it reads lighter than committed nodes.
const GHOST_DISK_RADIUS := Globals.VERTEX_RADIUS * 0.86

var _arrow: Polygon2D
var _ghost_vertex: Polygon2D

var _has_line: bool = false
var _line_from: Vector2
var _line_to: Vector2
var _stroke_color: Color


func _ready() -> void:
	z_as_relative = false
	z_index = 0

	_arrow = Polygon2D.new()
	_arrow.name = "GhostArrowhead"
	_arrow.visible = false
	add_child(_arrow)

	_ghost_vertex = Polygon2D.new()
	_ghost_vertex.name = "GhostVertexDisk"
	_ghost_vertex.polygon = _make_circle_polygon(GHOST_DISK_RADIUS, 42)
	_ghost_vertex.visible = false
	add_child(_ghost_vertex)

	hide_preview()


func _draw() -> void:
	if not _has_line:
		return
	draw_line(_line_from, _line_to, _stroke_color, Globals.EDGE_WIDTH, true)


func hide_preview() -> void:
	visible = false
	_has_line = false
	_arrow.visible = false
	_ghost_vertex.visible = false
	queue_redraw()


func sync_preview(graph: Graph, ctrl: GraphController, mouse_pos: Vector2) -> void:
	if graph == null or ctrl == null:
		hide_preview()
		return
	if not _should_show(ctrl):
		hide_preview()
		return

	var head: Vertex = graph.get_vertex(ctrl.link_head)
	if head == null:
		hide_preview()
		return

	var hover_id: int = graph.get_vertex_id_at(mouse_pos)
	var target: Vector2 = mouse_pos
	if hover_id != Globals.NOT_FOUND:
		var hv := graph.get_vertex(hover_id)
		if hv:
			target = hv.pos

	if head.pos.distance_squared_to(target) < 1.0:
		hide_preview()
		return

	var dir: Vector2 = head.pos.direction_to(target)
	var w: float = Globals.EDGE_WIDTH
	var span: float = maxf(head.pos.distance_to(target), 1.0)

	_stroke_color = Color(Globals.EDGE_COLOR.r, Globals.EDGE_COLOR.g, Globals.EDGE_COLOR.b, LINE_ALPHA)

	var start: Vector2 = (head.pos + dir * Globals.VERTEX_RADIUS).round()
	var end: Vector2

	if graph.is_directed():
		var inset: float = (
			GHOST_DISK_RADIUS + 4.0
			if hover_id == Globals.NOT_FOUND
			else Globals.VERTEX_RADIUS + 4.0
		)
		var tip: Vector2 = (target - dir * inset).round()
		var adims: Vector2 = EdgeArrowGeometry.get_arrow_dimensions(span, w)
		end = (tip - dir * (adims.x * 0.55)).round()

		_arrow.visible = true
		_arrow.color = _stroke_color
		_arrow.position = tip
		_arrow.rotation = dir.angle()
		_arrow.polygon = EdgeArrowGeometry.build_arrow_polygon(adims.x, adims.y)
	else:
		_arrow.visible = false
		if hover_id != Globals.NOT_FOUND:
			end = (target - dir * Globals.VERTEX_RADIUS).round()
		else:
			end = (mouse_pos - dir * (GHOST_DISK_RADIUS * 0.88)).round()

	visible = true
	_line_from = start
	_line_to = end
	_has_line = true
	queue_redraw()

	if hover_id == Globals.NOT_FOUND:
		_ghost_vertex.visible = true
		_ghost_vertex.position = mouse_pos.round()
		_ghost_vertex.color = Color(
			Globals.VERTEX_COLOR.r, Globals.VERTEX_COLOR.g, Globals.VERTEX_COLOR.b, GHOST_DISK_ALPHA
		)
	else:
		_ghost_vertex.visible = false


func _should_show(ctrl: GraphController) -> bool:
	if ctrl.link_head == Globals.NOT_FOUND:
		return false
	if Globals.current_state == Globals.State.EDGE:
		return true
	return Globals.current_state == Globals.State.CREATE and _ctrl_held()


func _ctrl_held() -> bool:
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return true
	# Right Control physical keycode (some backends).
	return Input.is_key_pressed(_PHYS_CTRL_R)


static func _make_circle_polygon(radius: float, points: int) -> PackedVector2Array:
	var arr: PackedVector2Array = []
	arr.resize(points)
	for i in points:
		var t: float = TAU * float(i) / float(points)
		arr[i] = Vector2(cos(t), sin(t)) * radius
	return arr
