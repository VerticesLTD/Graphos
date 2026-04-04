extends Node2D
class_name UIEdgeView

var weight_gap: float = 30.0
const MOUSE_DETECT_SENSITIVITY = 9.0
const EDGE_CLICK_EXTRA_TOLERANCE = 2.0
const BASE_WEIGHT_FONT_SIZE := 22
const MIN_WEIGHT_FONT_SIZE := 14
const CURVE_RENDER_SAMPLES := 16
const CURVE_HITTEST_SAMPLES := 18
const CURVE_AREA_SAMPLES := 12
var edge_data: Edge 

@onready var mouse_detection_area: Area2D = $MouseDetectionArea
@onready var collision_shape: CollisionShape2D = $MouseDetectionArea/CollisionShape2D
@onready var line_1: Line2D = $Line1
@onready var line_2: Line2D = $Line2
@onready var arrowhead: Polygon2D = $Arrowhead
@onready var weight_label: Label = $Weight
@onready var weight_edit: LineEdit = $WeightEdit

var draw_width_hovered: float = Globals.EDGE_WIDTH
var draw_color_hovered: Color = Globals.EDGE_COLOR

var is_hovered: bool = false
var is_manual_hover: bool = false
var _tween: Tween
var _weight_mid_local: Vector2 = Vector2.ZERO
var _last_src_pos: Vector2 = Vector2.INF
var _last_dst_pos: Vector2 = Vector2.INF
var _last_is_weighted := false
var _last_strategy_id := 0
var _last_curve_mode := false
const BIDIRECTIONAL_CURVE_FACTOR := 0.18
const BIDIRECTIONAL_CURVE_MIN := 22.0
const BIDIRECTIONAL_CURVE_MAX := 56.0

# --- Setup & Core ---

## Connects data signals to the view and initializes the edge.
func _ready() -> void:
	if edge_data:
		weight_label.text = _format_weight(edge_data.weight)
		_setup_detection_area()

		# Make sure to NOT create double connections(two vertices but one edge)
		# Data connections
		if not edge_data.state_changed.is_connected(refresh):
			edge_data.state_changed.connect(refresh)
		if not edge_data.vanished.is_connected(_on_edge_vanished):
			edge_data.vanished.connect(_on_edge_vanished)

		# Interaction connections
		if not mouse_detection_area.mouse_entered.is_connected(_on_mouse_entered):
			mouse_detection_area.mouse_entered.connect(_on_mouse_entered)
		if not mouse_detection_area.mouse_exited.is_connected(_on_mouse_exited):
			mouse_detection_area.mouse_exited.connect(_on_mouse_exited)
		Globals.app_state_changed.connect(_on_global_tool_changed)

		# Algorithm support
		if not edge_data.animation_requested.is_connected(_on_animation_requested):
			edge_data.animation_requested.connect(_on_animation_requested)
		
		# Input handling
		if not weight_edit.text_submitted.is_connected(_on_inline_weight_submitted):
			weight_edit.text_submitted.connect(_on_inline_weight_submitted)
		if not weight_edit.focus_exited.is_connected(_on_inline_weight_focus_exited):
			weight_edit.focus_exited.connect(_on_inline_weight_focus_exited)
		weight_edit.set_meta("inline_weight_editor", true)
		weight_edit.visible = false
		
		refresh()
	else:
		queue_free()


func _on_global_tool_changed() -> void:
	_clear_hover_if_tool_forbids_it()


func _clear_hover_if_tool_forbids_it() -> void:
	if not Globals.graph_hover_highlights_disabled():
		return
	if not is_hovered and not is_manual_hover:
		return
	if _tween:
		_tween.kill()
	is_hovered = false
	is_manual_hover = false
	draw_width_hovered = Globals.EDGE_WIDTH
	draw_color_hovered = edge_data.color
	_refresh_visual_style()


# --- Visual Refresh ---

## Central hub for visual updates. Runs only when the Edge Data signals a change.
func refresh() -> void:
	if not is_instance_valid(edge_data): return

	_refresh_visual_style()
	_refresh_geometry_if_needed()

func _refresh_visual_style() -> void:
	weight_label.text = _format_weight(edge_data.weight)
	weight_gap = 43.0 if weight_label.text.length() >= 3 else 30.0
	var fixed_width = Globals.EDGE_WIDTH
	if is_hovered:
		line_1.default_color = draw_color_hovered
		line_2.default_color = draw_color_hovered
		line_1.width = max(draw_width_hovered, fixed_width)
		line_2.width = max(draw_width_hovered, fixed_width)
		arrowhead.color = draw_color_hovered
	else:
		line_1.default_color = edge_data.color
		line_2.default_color = edge_data.color
		line_1.width = fixed_width
		line_2.width = fixed_width
		arrowhead.color = edge_data.color

func _refresh_geometry_if_needed() -> void:
	var graph := get_parent() as Graph
	var src_pos := edge_data.src.pos
	var dst_pos := edge_data.dst.pos
	var curve_mode := EdgeGeometry.should_draw_bidirectional_curve(edge_data, graph)
	var strategy_id := edge_data.strategy.get_instance_id() if edge_data.strategy else 0
	var needs_geometry := (
		src_pos != _last_src_pos
		or dst_pos != _last_dst_pos
		or edge_data.is_weighted != _last_is_weighted
		or strategy_id != _last_strategy_id
		or curve_mode != _last_curve_mode
	)
	if not needs_geometry:
		return
	_setup_lines_and_weight()
	_setup_detection_area()
	_last_src_pos = src_pos
	_last_dst_pos = dst_pos
	_last_is_weighted = edge_data.is_weighted
	_last_strategy_id = strategy_id
	_last_curve_mode = curve_mode

# --- Animations & Interaction ---

## Routes animation commands received from the Edge Data.
func _on_animation_requested(anim_name: String) -> void:
	if anim_name == "hover_start" and Globals.graph_hover_highlights_disabled():
		return
	match anim_name:
		"hover_start":
			is_hovered = true
			is_manual_hover = true
			_start_hover_animation()
		"hover_stop":
			manual_hover_stop()

## Triggers the start of the hover state on mouse enter.
func _on_mouse_entered() -> void:
	if Globals.graph_hover_highlights_disabled():
		return
	if is_hovered:
		return
	is_hovered = true
	_start_hover_animation()

## Triggers the end of the hover state on mouse exit.
func _on_mouse_exited() -> void:
	if not is_hovered or is_manual_hover: return
	_stop_hover_animation()

## Externally forces the hover animation to start.
func manual_hover_start() -> void:
	is_hovered = true
	is_manual_hover = true
	_start_hover_animation()

## Externally forces the hover animation to stop.
func manual_hover_stop() -> void:
	is_manual_hover = false
	_stop_hover_animation()

## Tweens the edge width and color to the highlighted hover state.
func _start_hover_animation() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "draw_width_hovered", Globals.EDGE_WIDTH * Globals.EDGE_HOVER_SCALE, Globals.EDGE_TWEEN_TIME)
	_tween.tween_property(self, "draw_color_hovered", Globals.EDGE_HOVER_COLOR, Globals.EDGE_TWEEN_TIME)
	
	# Keep hover smooth without rebuilding geometry/hitbox every frame.
	_tween.tween_method(func(_val): _refresh_visual_style(), 0.0, 1.0, Globals.EDGE_TWEEN_TIME)

## Tweens the edge safely back to its underlying data-driven state.
func _stop_hover_animation() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "draw_width_hovered", Globals.EDGE_WIDTH, Globals.EDGE_TWEEN_TIME)
	_tween.tween_property(self, "draw_color_hovered", edge_data.color, Globals.EDGE_TWEEN_TIME)
	
	_tween.tween_method(func(_val): _refresh_visual_style(), 0.0, 1.0, Globals.EDGE_TWEEN_TIME)

	_tween.chain().tween_callback(func(): 
		is_hovered = false
		is_manual_hover = false
		draw_color_hovered = edge_data.color 
		refresh() 
	)

# --- Geometry Helpers ---

## Draws and positions the arrowhead if this is a directed edge.
func _update_arrowhead(arrow_tip: Vector2, direction: Vector2, current_line_width: float, edge_distance: float) -> void:
	if not edge_data.strategy is DirectedStrategy:
		arrowhead.visible = false
		return
		
	arrowhead.visible = true
	arrowhead.position = arrow_tip.round()
	arrowhead.rotation = direction.angle()
	var arrow_dimensions := EdgeArrowGeometry.get_arrow_dimensions(edge_distance, current_line_width)
	arrowhead.polygon = EdgeArrowGeometry.build_arrow_polygon(arrow_dimensions.x, arrow_dimensions.y)
		
## Recalculates line points to leave a gap for the weight label.
func _setup_lines_and_weight() -> void:
	var src_pos = edge_data.src.pos.round()
	var dst_pos = edge_data.dst.pos.round()
	var actual_dist = src_pos.distance_to(dst_pos)
	_update_weight_label_metrics(actual_dist)

	line_1.clear_points()
	line_2.clear_points()

	var graph := get_parent() as Graph
	var draw_curved := EdgeGeometry.should_draw_bidirectional_curve(edge_data, graph)
	if draw_curved:
		_draw_bidirectional_curved_edge(src_pos, dst_pos, actual_dist)
	else:
		_draw_linear_edge(src_pos, dst_pos, actual_dist)

func _draw_linear_edge(src_pos: Vector2, dst_pos: Vector2, actual_dist: float) -> void:
	var direction = src_pos.direction_to(dst_pos)
	var visual_dst = (dst_pos - (direction * Globals.VERTEX_RADIUS)).round()
	var visual_start = (src_pos + (direction * Globals.VERTEX_RADIUS)).round()
	var arrow_tip = visual_dst

	if edge_data.strategy is DirectedStrategy:
		line_1.end_cap_mode = Line2D.LINE_CAP_NONE
		line_2.end_cap_mode = Line2D.LINE_CAP_NONE
		arrow_tip = (dst_pos - (direction * (Globals.VERTEX_RADIUS + 4.0))).round()
		var arrow_length = EdgeArrowGeometry.get_arrow_dimensions(actual_dist, line_1.width).x
		visual_dst = (arrow_tip - (direction * (arrow_length * 0.55))).round()
	else:
		line_1.end_cap_mode = Line2D.LINE_CAP_ROUND
		line_2.end_cap_mode = Line2D.LINE_CAP_ROUND

	var true_mid = src_pos.lerp(dst_pos, 0.5).round()
	if edge_data.strategy is DirectedStrategy:
		true_mid = visual_start.lerp(visual_dst, 0.5).round()
	var offset = direction * (weight_gap / 2.0)

	if edge_data.is_weighted and _can_draw_inline_weight(actual_dist):
		_draw_weighted_edge(visual_start, visual_dst, true_mid, offset)
	else:
		_draw_simple_edge(visual_start, visual_dst)

	if edge_data.strategy is DirectedStrategy:
		_update_arrowhead(arrow_tip, direction, line_1.width, actual_dist)
	else:
		arrowhead.visible = false

func _draw_bidirectional_curved_edge(src_pos: Vector2, dst_pos: Vector2, actual_dist: float) -> void:
	line_1.end_cap_mode = Line2D.LINE_CAP_NONE
	line_2.end_cap_mode = Line2D.LINE_CAP_NONE

	var control = EdgeGeometry.get_bidirectional_control_point(
		edge_data,
		src_pos,
		dst_pos,
		BIDIRECTIONAL_CURVE_FACTOR,
		BIDIRECTIONAL_CURVE_MIN,
		BIDIRECTIONAL_CURVE_MAX
	)
	var tangent_start = EdgeGeometry.quadratic_tangent(src_pos, control, dst_pos, 0.0).normalized()
	var tangent_end = EdgeGeometry.quadratic_tangent(src_pos, control, dst_pos, 1.0).normalized()
	var visual_start = (src_pos + (tangent_start * Globals.VERTEX_RADIUS)).round()
	var arrow_tip = (dst_pos - (tangent_end * (Globals.VERTEX_RADIUS + 4.0))).round()
	var arrow_length = EdgeArrowGeometry.get_arrow_dimensions(actual_dist, line_1.width).x
	var visual_end = (arrow_tip - (tangent_end * (arrow_length * 0.55))).round()

	if edge_data.is_weighted and _can_draw_inline_weight(actual_dist):
		_draw_weighted_curved_edge(visual_start, control, visual_end, actual_dist)
	else:
		_draw_simple_curved_edge(visual_start, control, visual_end)

	_update_arrowhead(arrow_tip, tangent_end, line_1.width, actual_dist)

func _draw_simple_curved_edge(start: Vector2, control: Vector2, finish: Vector2) -> void:
	if not _is_inline_editor_active():
		weight_label.visible = false
	var points = EdgeGeometry.sample_quadratic(start, control, finish, 0.0, 1.0, CURVE_RENDER_SAMPLES)
	_add_points_to_line(line_1, points)

func _draw_weighted_curved_edge(start: Vector2, control: Vector2, finish: Vector2, actual_dist: float) -> void:
	var center_t := 0.5
	var local_tangent = EdgeGeometry.quadratic_tangent(start, control, finish, center_t).normalized()
	var dt = clamp((weight_gap * 0.5) / max(actual_dist, 1.0), 0.04, 0.22)
	var left_t = clamp(center_t - dt, 0.0, 1.0)
	var right_t = clamp(center_t + dt, 0.0, 1.0)

	_weight_mid_local = EdgeGeometry.quadratic_point(start, control, finish, center_t)
	if not _is_inline_editor_active():
		weight_label.visible = true
	weight_label.position = (_weight_mid_local - (weight_label.size / 2.0)).round()
	_update_weight_label_transform_with_direction(_weight_mid_local, local_tangent)

	var first_points = EdgeGeometry.sample_quadratic(start, control, finish, 0.0, left_t, 10)
	var second_points = EdgeGeometry.sample_quadratic(start, control, finish, right_t, 1.0, 10)
	_add_points_to_line(line_1, first_points)
	_add_points_to_line(line_2, second_points)

func _update_weight_label_metrics(actual_dist: float) -> void:
	var adaptive_font_size = _get_adaptive_weight_font_size(actual_dist)
	weight_label.add_theme_font_size_override("font_size", adaptive_font_size)
	var base_gap = 43.0 if weight_label.text.length() >= 3 else 30.0
	weight_gap = base_gap * (float(adaptive_font_size) / float(BASE_WEIGHT_FONT_SIZE))

func _get_adaptive_weight_font_size(actual_dist: float) -> int:
	var t = inverse_lerp(70.0, 150.0, actual_dist)
	return int(round(lerp(float(MIN_WEIGHT_FONT_SIZE), float(BASE_WEIGHT_FONT_SIZE), clamp(t, 0.0, 1.0))))

func _can_draw_inline_weight(actual_dist: float) -> bool:
	var min_required = max(38.0, weight_gap * 1.35)
	if edge_data.strategy is DirectedStrategy:
		min_required += 10.0
	return actual_dist >= min_required

## Helper: Line segments stop at visual_dst, but gap is centered at true_mid
func _draw_weighted_edge(start: Vector2, end: Vector2, mid: Vector2, offset: Vector2) -> void:
	_weight_mid_local = mid
	if not _is_inline_editor_active():
		weight_label.visible = true
	# Force the label to the chosen midpoint anchor.
	weight_label.position = (mid - (weight_label.size / 2.0)).round()
	_update_weight_label_transform(mid) # Handles rotation
	
	line_1.add_point(start)
	line_1.add_point((mid - offset).round())
	
	line_2.add_point((mid + offset).round())
	line_2.add_point(end)

func _draw_simple_edge(start: Vector2, end: Vector2) -> void:
	if not _is_inline_editor_active():
		weight_label.visible = false
	line_1.add_point(start)
	line_1.add_point(end)
		
## Centers and rotates the weight label within the line gap.
func _update_weight_label_transform(mid_point: Vector2) -> void:
	var pos1 = edge_data.src.pos.round()
	var pos2 = edge_data.dst.pos.round()
	var direction = pos2-pos1
	var angle = direction.angle()

	weight_label.pivot_offset = weight_label.size / 2.0
	weight_label.position = (mid_point - (weight_label.size / 2.0)).round()

	if abs(angle) > PI / 2: angle += PI
	weight_label.rotation = angle

func _update_weight_label_transform_with_direction(mid_point: Vector2, direction: Vector2) -> void:
	var angle = direction.angle()
	weight_label.pivot_offset = weight_label.size / 2.0
	weight_label.position = (mid_point - (weight_label.size / 2.0)).round()
	if abs(angle) > PI / 2:
		angle += PI
	weight_label.rotation = angle

## Determines if the weight label should be drawn based on user settings.
## Rebuilds the Area2D hit-box used for hover. Precise clicks are handled in _input().
func _setup_detection_area() -> void:
	var pos1 = edge_data.src.pos
	var pos2  = edge_data.dst.pos
	var width = Globals.EDGE_WIDTH + MOUSE_DETECT_SENSITIVITY
	var length: float
	var midpoint: Vector2
	var rotation_angle: float

	var graph := get_parent() as Graph
	var visual_start: Vector2
	var visual_end: Vector2
	if EdgeGeometry.should_draw_bidirectional_curve(edge_data, graph):
		var control = EdgeGeometry.get_bidirectional_control_point(
			edge_data,
			pos1,
			pos2,
			BIDIRECTIONAL_CURVE_FACTOR,
			BIDIRECTIONAL_CURVE_MIN,
			BIDIRECTIONAL_CURVE_MAX
		)
		var start_tangent = EdgeGeometry.quadratic_tangent(pos1, control, pos2, 0.0).normalized()
		var end_tangent = EdgeGeometry.quadratic_tangent(pos1, control, pos2, 1.0).normalized()
		visual_start = pos1 + (start_tangent * Globals.VERTEX_RADIUS)
		visual_end = pos2 - (end_tangent * Globals.VERTEX_RADIUS)

		# Approximate arc length with polyline segments for better hit area size.
		var curve_points = EdgeGeometry.sample_quadratic(visual_start, control, visual_end, 0.0, 1.0, CURVE_AREA_SAMPLES)
		length = EdgeGeometry.estimate_polyline_length(curve_points)

		midpoint = EdgeGeometry.quadratic_point(visual_start, control, visual_end, 0.5)
		var mid_tangent = EdgeGeometry.quadratic_tangent(visual_start, control, visual_end, 0.5).normalized()
		rotation_angle = mid_tangent.angle()

		# Broaden rectangle by bend so clicks follow the curved path.
		var bend = control.distance_to(pos1.lerp(pos2, 0.5))
		width += clamp(bend * 0.45, 6.0, 24.0)
	else:
		var draw_positions = EdgeGeometry.get_linear_visual_start_end(pos1, pos2, Globals.VERTEX_RADIUS)
		visual_start = draw_positions[0]
		visual_end = draw_positions[1]
		length = visual_start.distance_to(visual_end)
		midpoint = (pos1 + pos2) / 2.0
		rotation_angle = visual_start.angle_to_point(visual_end)

	mouse_detection_area.position = midpoint
	mouse_detection_area.rotation = rotation_angle

	if not collision_shape.shape is RectangleShape2D:
		collision_shape.shape = RectangleShape2D.new()
	
	var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	shape.size = Vector2(length, width)

func _add_points_to_line(line: Line2D, points: PackedVector2Array) -> void:
	for p in points:
		line.add_point(p)

func _graph_controller_for_this_graph() -> GraphController:
	var g := get_parent() as Graph
	if g == null:
		return null
	var root := g.get_parent()
	if root == null:
		return null
	for child in root.get_children():
		if child is GraphController and (child as GraphController).graph == g:
			return child as GraphController
	for child in root.get_children():
		if child is GraphController:
			return child as GraphController
	return null

## If we handled every LMB on the stroke, vertex clicks near endpoints would never reach the graph
## (polyline hit is fat). Same defer rules as RMB: vertex wins, or multi-select box wins.
func _should_defer_edge_click_to_controller(mouse_world: Vector2) -> bool:
	var graph := get_parent() as Graph
	if graph == null:
		return false
	if graph.get_vertex_id_at(mouse_world) != Globals.NOT_FOUND:
		return true
	var gctrl := _graph_controller_for_this_graph()
	if gctrl == null:
		return false
	if gctrl.selection_buffer.size() > 1 and gctrl.selection_bounds.has_point(mouse_world):
		return true
	return false

# --- Weight Editor ---

func _input(event: InputEvent) -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_button_event := event as InputEventMouseButton
	if not mouse_button_event.pressed:
		return

	var mouse_world = get_global_mouse_position()
	if not _is_mouse_over_edge(mouse_world):
		return

	if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
		if _should_defer_edge_click_to_controller(mouse_world):
			return
		_open_edge_context_menu(mouse_button_event.position)
		get_viewport().set_input_as_handled()
		return

	if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
		if _should_defer_edge_click_to_controller(mouse_world):
			return
		get_viewport().set_input_as_handled()
		if edge_data.is_weighted:
			_start_inline_weight_edit()
		return

func _open_edge_context_menu(screen_pos: Vector2) -> void:
	var graph := get_parent() as Graph
	if graph == null:
		return

	var scene_root := graph.get_parent()
	if scene_root == null:
		return

	var popup_menu = scene_root.get_node_or_null("CanvasLayer/PopupMenuLayer")
	if popup_menu == null:
		popup_menu = scene_root.get_node_or_null("GraphController/PopupMenu")
	if popup_menu == null:
		return

	if Globals.active_weight_editor:
		Globals.active_weight_editor.release_focus()
		Globals.active_weight_editor = null

	popup_menu.open_for_edge(edge_data, graph.get_global_mouse_position(), screen_pos)

func _is_mouse_over_edge(mouse_world_pos: Vector2) -> bool:
	var points = _get_edge_hit_test_polyline()
	var threshold = Globals.EDGE_WIDTH * 0.5 + MOUSE_DETECT_SENSITIVITY + EDGE_CLICK_EXTRA_TOLERANCE
	# Slightly larger than visual stroke so users don't need pixel-perfect clicks.
	return EdgeGeometry.is_point_near_polyline(mouse_world_pos, points, threshold)

func _get_edge_hit_test_polyline() -> PackedVector2Array:
	var src_pos = edge_data.src.pos
	var dst_pos = edge_data.dst.pos
	var graph := get_parent() as Graph
	var visual_start: Vector2
	var visual_end: Vector2

	if EdgeGeometry.should_draw_bidirectional_curve(edge_data, graph):
		var control = EdgeGeometry.get_bidirectional_control_point(
			edge_data,
			src_pos,
			dst_pos,
			BIDIRECTIONAL_CURVE_FACTOR,
			BIDIRECTIONAL_CURVE_MIN,
			BIDIRECTIONAL_CURVE_MAX
		)
		var tangent_start = EdgeGeometry.quadratic_tangent(src_pos, control, dst_pos, 0.0).normalized()
		var tangent_end = EdgeGeometry.quadratic_tangent(src_pos, control, dst_pos, 1.0).normalized()
		visual_start = src_pos + (tangent_start * Globals.VERTEX_RADIUS)
		visual_end = dst_pos - (tangent_end * Globals.VERTEX_RADIUS)
		return EdgeGeometry.sample_quadratic(visual_start, control, visual_end, 0.0, 1.0, CURVE_HITTEST_SAMPLES)

	var linear_positions = EdgeGeometry.get_linear_visual_start_end(src_pos, dst_pos, Globals.VERTEX_RADIUS)
	visual_start = linear_positions[0]
	visual_end = linear_positions[1]
	var points := PackedVector2Array()
	points.append(visual_start)
	points.append(visual_end)
	return points

func _start_inline_weight_edit() -> void:
	if Globals.active_weight_editor and Globals.active_weight_editor != weight_edit:
		Globals.active_weight_editor.release_focus()

	weight_edit.text = _format_weight(edge_data.weight)
	weight_edit.custom_minimum_size = Vector2(max(22.0, weight_label.size.x + 8.0), max(22.0, weight_label.size.y + 4.0))
	_position_inline_weight_editor()
	weight_edit.visible = true
	weight_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	weight_label.visible = false
	Globals.active_weight_editor = weight_edit
	weight_edit.grab_focus()
	weight_edit.select_all()

func _position_inline_weight_editor() -> void:
	var center = to_global(_weight_mid_local)
	var edit_size = weight_edit.get_combined_minimum_size()
	weight_edit.global_position = (center - (edit_size / 2.0)).round()
	weight_edit.rotation = 0.0

func _on_inline_weight_submitted(new_text: String) -> void:
	_commit_inline_weight_edit(new_text)

func _on_inline_weight_focus_exited() -> void:
	_commit_inline_weight_edit(weight_edit.text)

## Submits the new weight to the CommandManager and cleans up the UI.
func _commit_inline_weight_edit(new_text: String) -> void:
	if Globals.active_weight_editor != weight_edit:
		return

	if edge_data.is_algorithm_locked:
		Notify.show_error("Cannot change weight: this edge is part of a running algorithm.")
		_finish_inline_weight_edit()
		return

	var parsed := new_text.strip_edges().replace(",", ".")
	if parsed.is_valid_int() or parsed.is_valid_float():
		var cmd = ChangeEdgeWeightCommand.new(edge_data, parsed.to_float())
		CommandManager.execute(cmd)

	_finish_inline_weight_edit()

func _finish_inline_weight_edit() -> void:
	weight_edit.release_focus()
	weight_edit.visible = false
	weight_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weight_label.visible = true
	Globals.active_weight_editor = null
	refresh()

func _is_inline_editor_active() -> bool:
	return is_instance_valid(weight_edit) and weight_edit.visible

func _format_weight(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.001))

## Handles the vanished signal from the data layer.
func _on_edge_vanished(_killer: Vertex) -> void:
	# TBD: Optional: play a fade-out animation before queue_free!
	queue_free()
