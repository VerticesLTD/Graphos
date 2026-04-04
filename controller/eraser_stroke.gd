extends RefCounted

const PENDING_COLOR := Color(0.74, 0.74, 0.78)
const TRAIL_MAX_POINTS := 22
const TRAIL_WIDTH := 7.0

var _mouse_actions: Node
var active := false

var _pending_vertices: Array[Vertex] = []
var _pending_edges: Array[Edge] = []
var _vertex_ids: Dictionary = {}
var _edge_keys: Dictionary = {}
var _orig_vertex_colors: Dictionary = {}
var _orig_edge_colors: Dictionary = {}
var _trail: PackedVector2Array = PackedVector2Array()
var _trail_line: Line2D


func _init(mouse_actions: Node) -> void:
	_mouse_actions = mouse_actions
	Globals.app_state_changed.connect(_on_app_state_changed)


func _graph() -> Graph:
	return _mouse_actions.controller.graph as Graph


func _controller() -> GraphController:
	return _mouse_actions.controller as GraphController


func _on_app_state_changed() -> void:
	if active and Globals.current_state != Globals.State.ERASER:
		cancel_silent()


func start_session(pos: Vector2) -> void:
	active = true
	_pending_vertices.clear()
	_pending_edges.clear()
	_vertex_ids.clear()
	_edge_keys.clear()
	_orig_vertex_colors.clear()
	_orig_edge_colors.clear()
	_trail = PackedVector2Array()
	_trail.append(pos)
	_create_trail()
	_check_at(pos)


func update_motion(pos: Vector2) -> void:
	if not active:
		return
	_trail.append(pos)
	if _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)
	_update_trail()
	_check_at(pos)


func cancel_to_selection() -> void:
	cancel_silent()
	Globals.current_state = Globals.State.SELECTION


func cancel_silent() -> void:
	active = false
	_restore_colors()
	_clear_maps()
	_destroy_trail()


func commit() -> void:
	active = false
	_destroy_trail()
	if _pending_vertices.is_empty() and _pending_edges.is_empty():
		_clear_maps()
		return
	_restore_colors()
	var standalone: Array[Edge] = []
	for e in _pending_edges:
		if not _vertex_ids.has(e.src.id) and not _vertex_ids.has(e.dst.id):
			standalone.append(e)
	var cmd := BulkEraseCommand.new(_graph(), _pending_vertices, standalone, _controller())
	CommandManager.execute(cmd)
	_clear_maps()


func _check_at(pos: Vector2) -> void:
	var g := _graph()
	var v_id := g.get_vertex_id_at(pos)
	if v_id != Globals.NOT_FOUND:
		if not _vertex_ids.has(v_id):
			var v := g.get_vertex(v_id)
			if v:
				_mark_vertex(v)
		return
	var edge := g.get_edge_at(pos)
	if edge:
		_mark_edge(edge)


func _mark_vertex(v: Vertex) -> void:
	_vertex_ids[v.id] = true
	_orig_vertex_colors[v] = v.color
	_pending_vertices.append(v)
	v.color = PENDING_COLOR
	var e: Edge = v.edges
	while e:
		_paint_edge_preview(e)
		e = e.next
	for inc in _graph().get_incoming_edges(v):
		_paint_edge_preview(inc)


func _mark_edge(edge: Edge) -> void:
	var key := _pair_key(edge.src.id, edge.dst.id)
	if _edge_keys.has(key):
		return
	_edge_keys[key] = true
	_pending_edges.append(edge)
	_paint_edge_preview(edge)
	if not (edge.strategy is DirectedStrategy):
		var rev := _graph().get_edge(edge.dst, edge.src)
		if rev:
			_paint_edge_preview(rev)


func _paint_edge_preview(edge: Edge) -> void:
	if not _orig_edge_colors.has(edge):
		_orig_edge_colors[edge] = edge.color
		edge.color = PENDING_COLOR


func _restore_colors() -> void:
	for v in _orig_vertex_colors:
		if is_instance_valid(v):
			v.color = _orig_vertex_colors[v]
	for e in _orig_edge_colors:
		if is_instance_valid(e):
			e.color = _orig_edge_colors[e]


func _clear_maps() -> void:
	_pending_vertices.clear()
	_pending_edges.clear()
	_vertex_ids.clear()
	_edge_keys.clear()
	_orig_vertex_colors.clear()
	_orig_edge_colors.clear()
	_trail = PackedVector2Array()


func _pair_key(a: int, b: int) -> String:
	return str(mini(a, b)) + "_" + str(maxi(a, b))


func _create_trail() -> void:
	_destroy_trail()
	_trail_line = Line2D.new()
	_trail_line.width = TRAIL_WIDTH
	_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_line.z_index = 10
	var grad := Gradient.new()
	grad.set_color(0, Color(0.62, 0.62, 0.68, 0.0))
	grad.set_color(1, Color(0.62, 0.62, 0.68, 0.72))
	_trail_line.gradient = grad
	_graph().add_child(_trail_line)


func _update_trail() -> void:
	if not is_instance_valid(_trail_line):
		return
	_trail_line.clear_points()
	for p in _trail:
		_trail_line.add_point(p)


func _destroy_trail() -> void:
	if is_instance_valid(_trail_line):
		_trail_line.queue_free()
	_trail_line = null
