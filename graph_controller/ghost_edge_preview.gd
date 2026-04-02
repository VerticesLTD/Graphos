extends Node2D
## Ctrl-chain ghost: dashed segment drawn in _draw() (reliable); arrow + ghost disk as Polygon2D.
class_name GhostEdgePreview

const _PHYS_CTRL_R := 4194328
const LINE_ALPHA := 0.42
const DASH_LEN := 8.0
const GAP_LEN := 6.0

var _arrow: Polygon2D
var _ghost_vertex: Polygon2D

var _has_line: bool = false
var _line_from: Vector2
var _line_to: Vector2


func _ready() -> void:
	z_as_relative = false
	z_index = 0

	_arrow = Polygon2D.new()
	_arrow.name = "GhostArrowhead"
	_arrow.visible = false
	add_child(_arrow)

	_ghost_vertex = Polygon2D.new()
	_ghost_vertex.name = "GhostVertexDisk"
	_ghost_vertex.polygon = _make_circle_polygon(Globals.VERTEX_RADIUS, 40)
	_ghost_vertex.visible = false
	add_child(_ghost_vertex)

	hide_preview()


func _draw() -> void:
	if not _has_line:
		return
	var col := Color(
		Globals.EDGE_COLOR.r, Globals.EDGE_COLOR.g, Globals.EDGE_COLOR.b, LINE_ALPHA
	)
	_draw_dashed_segment(_line_from, _line_to, col, Globals.EDGE_WIDTH)


func hide_preview() -> void:
	visible = false
	_has_line = false
	if _arrow:
		_arrow.visible = false
	if _ghost_vertex:
		_ghost_vertex.visible = false
	queue_redraw()


## mouse_pos must match Graph.get_vertex_id_at / Vertex.pos space (same as graph.get_global_mouse_position()).
func sync_preview(graph: Graph, ctrl: GraphController, mouse_pos: Vector2) -> void:
	if not graph or not ctrl:
		hide_preview()
		return

	if not _should_show(ctrl, graph):
		hide_preview()
		return

	var head_id: int = ctrl.link_head
	var head: Vertex = graph.get_vertex(head_id)
	if head == null:
		hide_preview()
		return

	var hover_id: int = graph.get_vertex_id_at(mouse_pos)
	var to_pos: Vector2 = mouse_pos
	if hover_id != Globals.NOT_FOUND:
		var hv: Vertex = graph.get_vertex(hover_id)
		if hv:
			to_pos = hv.pos

	var raw_dist: float = head.pos.distance_to(to_pos)
	if raw_dist < 1.0:
		hide_preview()
		return

	var direction: Vector2 = head.pos.direction_to(to_pos)
	var directed: bool = graph.is_directed()
	var line_width: float = Globals.EDGE_WIDTH
	var actual_dist: float = maxf(raw_dist, 1.0)

	var visual_start: Vector2 = (head.pos + direction * Globals.VERTEX_RADIUS).round()
	var visual_end: Vector2
	var arrow_tip: Vector2
	var arrow_dims: Vector2

	if directed:
		if hover_id != Globals.NOT_FOUND:
			arrow_tip = (to_pos - (direction * (Globals.VERTEX_RADIUS + 4.0))).round()
		else:
			arrow_tip = (mouse_pos - (direction * (Globals.VERTEX_RADIUS + 4.0))).round()
		arrow_dims = EdgeArrowGeometry.get_arrow_dimensions(actual_dist, line_width)
		var arrow_length: float = arrow_dims.x
		visual_end = (arrow_tip - (direction * (arrow_length * 0.55))).round()

		_arrow.visible = true
		_arrow.color = Color(
			Globals.EDGE_COLOR.r, Globals.EDGE_COLOR.g, Globals.EDGE_COLOR.b, LINE_ALPHA
		)
		_arrow.position = arrow_tip
		_arrow.rotation = direction.angle()
		_arrow.polygon = EdgeArrowGeometry.build_arrow_polygon(arrow_dims.x, arrow_dims.y)
	else:
		_arrow.visible = false
		if hover_id != Globals.NOT_FOUND:
			visual_end = (to_pos - direction * Globals.VERTEX_RADIUS).round()
		else:
			visual_end = (mouse_pos - direction * (Globals.VERTEX_RADIUS * 0.82)).round()

	visible = true
	_line_from = visual_start
	_line_to = visual_end
	_has_line = true
	queue_redraw()

	if hover_id == Globals.NOT_FOUND:
		_ghost_vertex.visible = true
		_ghost_vertex.position = mouse_pos.round()
		_ghost_vertex.color = Color(
			Globals.VERTEX_COLOR.r, Globals.VERTEX_COLOR.g, Globals.VERTEX_COLOR.b, 0.2
		)
	else:
		_ghost_vertex.visible = false


func _should_show(ctrl: GraphController, graph: Graph) -> bool:
	if Globals.current_state != Globals.State.CREATE:
		return false
	if ctrl.link_head == Globals.NOT_FOUND:
		return false
	if not _ctrl_modifier_held():
		return false
	return true


func _ctrl_modifier_held() -> bool:
	if Input.is_key_pressed(KEY_CTRL):
		return true
	if Input.is_key_pressed(KEY_META):
		return true
	return Input.is_physical_key_pressed(_PHYS_CTRL_R)


func _draw_dashed_segment(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.5:
		return
	var dir := d / len
	var t := 0.0
	while t < len:
		var seg_end: float = minf(t + DASH_LEN, len)
		draw_line(from + dir * t, from + dir * seg_end, color, width, true)
		t = seg_end + GAP_LEN


static func _make_circle_polygon(radius: float, points: int) -> PackedVector2Array:
	var arr: PackedVector2Array = []
	for i in points:
		var t: float = TAU * float(i) / float(points)
		arr.append(Vector2(cos(t), sin(t)) * radius)
	return arr
