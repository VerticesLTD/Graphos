extends Node2D
class_name UIEdgeView

var weight_gap: float = 30.0
const MOUSE_DETECT_SENSITIVITY = 9.0
var edge_data: Edge 

@onready var mouse_detection_area: Area2D = $MouseDetectionArea
@onready var collision_shape: CollisionShape2D = $MouseDetectionArea/CollisionShape2D
@onready var line_1: Line2D = $Line1
@onready var line_2: Line2D = $Line2
@onready var arrowhead: Polygon2D = $Arrowhead
@onready var weight_label: Label = $Weight

var draw_width_hovered: float = Globals.EDGE_WIDTH
var draw_color_hovered: Color = Globals.EDGE_COLOR

var is_hovered: bool = false
var is_manual_hover: bool = false
var _tween: Tween

# --- Setup & Core ---

## Connects data signals to the view and initializes the edge.
func _ready() -> void:
	if edge_data:
		weight_label.text = str(edge_data.weight)
		_setup_detection_area()

		# Connections
		edge_data.state_changed.connect(refresh)
		edge_data.vanished.connect(_on_edge_vanished)

		# Interaction connections
		mouse_detection_area.mouse_entered.connect(_on_mouse_entered)
		mouse_detection_area.mouse_exited.connect(_on_mouse_exited)
		
		# Algorithm support
		edge_data.animation_requested.connect(_on_animation_requested)
		
		# Input handling
		mouse_detection_area.input_event.connect(_on_mouse_detection_area_input_event)
		
		refresh()
	else:
		queue_free()

# --- Visual Refresh ---

## Central hub for visual updates. Runs only when the Edge Data signals a change.
func refresh() -> void:
	if not is_instance_valid(edge_data): return

	weight_label.text = str(edge_data.weight)
	weight_gap = 43.0 if weight_label.text.length() >= 3 else 30.0
	
	var width_by_weight = clampf(Globals.EDGE_WIDTH * edge_data.weight / 5.0, 5.0, 15.0)

	if is_hovered:
		line_1.default_color = draw_color_hovered
		line_2.default_color = draw_color_hovered
		line_1.width = max(draw_width_hovered, width_by_weight)
		line_2.width = max(draw_width_hovered, width_by_weight)
		arrowhead.color = draw_color_hovered
	else:
		line_1.default_color = edge_data.color
		line_2.default_color = edge_data.color
		line_1.width = width_by_weight
		line_2.width = width_by_weight
		arrowhead.color = edge_data.color

	_setup_lines_and_weight()
	_setup_detection_area()

# --- Animations & Interaction ---

## Routes animation commands received from the Edge Data.
func _on_animation_requested(anim_name: String) -> void:
	match anim_name:
		"hover_start":
			is_hovered = true
			is_manual_hover = true
			_start_hover_animation()
		"hover_stop":
			manual_hover_stop()

## Triggers the start of the hover state on mouse enter.
func _on_mouse_entered() -> void:
	if is_hovered: return
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
	
	# Forces the Line2D nodes to visually update frame-by-frame
	_tween.tween_method(func(_val): refresh(), 0.0, 1.0, Globals.EDGE_TWEEN_TIME)

## Tweens the edge safely back to its underlying data-driven state.
func _stop_hover_animation() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "draw_width_hovered", Globals.EDGE_WIDTH, Globals.EDGE_TWEEN_TIME)
	_tween.tween_property(self, "draw_color_hovered", edge_data.color, Globals.EDGE_TWEEN_TIME)
	
	_tween.tween_method(func(_val): refresh(), 0.0, 1.0, Globals.EDGE_TWEEN_TIME)

	_tween.chain().tween_callback(func(): 
		is_hovered = false
		is_manual_hover = false
		draw_color_hovered = edge_data.color 
		refresh() 
	)

# --- Geometry Helpers ---

## Draws and positions the arrowhead if this is a directed edge.
func _update_arrowhead(pos1: Vector2, pos2: Vector2, current_line_width: float) -> void:
	# If the data says this is Undirected, hide the arrow and stop.
	if not edge_data.strategy is DirectedStrategy:
		arrowhead.visible = false
		return
		
	arrowhead.visible = true
	
	# 1. Find the exact edge of the destination vertex
	var direction = pos1.direction_to(pos2)
	var visual_end = pos2 - (direction * Globals.VERTEX_RADIUS)
	
	# 2. Position and rotate the Polygon2D
	arrowhead.position = visual_end
	arrowhead.rotation = direction.angle()
	
	# 3. Calculate dynamic size based on the line width
	var arrow_length = current_line_width * 3.0
	var arrow_width = current_line_width * 1.5
	
	# 4. Define a triangle pointing right (0 degrees)
	# Point 1: Tip of the arrow (0,0)
	# Point 2: Top back corner
	# Point 3: Bottom back corner
	var points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-arrow_length, -arrow_width),
		Vector2(-arrow_length, arrow_width)
	])
	
	arrowhead.polygon = points
	
## Recalculates line points to leave a gap for the weight label.
func _setup_lines_and_weight() -> void:
	var pos1 = edge_data.src.pos
	var pos2 = edge_data.dst.pos
	var mid_point = pos1.lerp(pos2,0.5)
	var direction = (pos2-pos1).normalized()
	var offset = direction * (weight_gap / 2.0)
	var length = pos1.distance_to(pos2)

	var line_1_end = mid_point - offset
	var line_2_start = mid_point + offset

	if edge_data.is_weighted and length > (weight_gap * 3):
		# WEIGHTED
		weight_label.visible = true
		_update_weight_label_transform()
		line_1.clear_points()
		line_2.clear_points()
		line_1.add_point(pos1)
		line_1.add_point(line_1_end)
		line_2.add_point(line_2_start)
		line_2.add_point(pos2)
	else:
		# UNWEIGHTED (or too short): Draw one continuous solid line
		weight_label.visible = false
		line_1.clear_points()
		line_2.clear_points() # Hide the second half completely
		
		# Line 1 does all the work
		line_1.add_point(pos1)
		line_1.add_point(pos2)
	
	# Arrowhead draws last so it always sits on top of whatever line_1 did
	_update_arrowhead(pos1, pos2, line_1.width)
	
## Centers and rotates the weight label within the line gap.
func _update_weight_label_transform() -> void:
	var pos1 = edge_data.src.pos
	var pos2 = edge_data.dst.pos
	var mid_point = (pos1 + pos2) / 2.0
	var direction = pos2-pos1
	var angle = direction.angle()

	weight_label.pivot_offset = weight_label.size / 2.0
	weight_label.position = mid_point - (weight_label.size / 2.0)

	if abs(angle) > PI / 2: angle += PI
	weight_label.rotation = angle

## Determines if the weight label should be drawn based on user settings.
func _should_display_weight() -> bool:
	return true	

## Rebuilds the clickable hit-box to match the visual line perfectly.
func _setup_detection_area() -> void:
	var pos1 = edge_data.src.pos
	var pos2  = edge_data.dst.pos
	var draw_positions = _get_visual_start_end(pos1,pos2)
	var visual_start = draw_positions[0]
	var visual_end = draw_positions[1]

	var width = Globals.EDGE_WIDTH + MOUSE_DETECT_SENSITIVITY
	var length: float = visual_start.distance_to(visual_end)
	var midpoint: Vector2 = (pos1 + pos2) / 2.0
	var rotation_angle: float = visual_start.angle_to_point(visual_end)

	mouse_detection_area.position = midpoint
	mouse_detection_area.rotation = rotation_angle

	if not collision_shape.shape is RectangleShape2D:
		collision_shape.shape = RectangleShape2D.new()
	
	var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	shape.size = Vector2(length, width)

## Calculates where the edge visually starts/ends to avoid overlapping the vertex.
func _get_visual_start_end(pos1: Vector2, pos2: Vector2) -> Array[Vector2]:
	var direction = pos1.direction_to(pos2)
	var visual_start = pos1 + (direction * Globals.VERTEX_RADIUS)
	var visual_end = pos2 - (direction * Globals.VERTEX_RADIUS)
	return [visual_start,visual_end]

# --- Weight Editor ---

## Detects double-clicks on the line to open the weight editing UI.
func _on_mouse_detection_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and edge_data.is_weighted:
			_spawn_weight_editor()

## Spawns a floating LineEdit node for the user to type a new weight.
func _spawn_weight_editor() -> void:
	if Globals.active_weight_editor:
		Globals.active_weight_editor.queue_free()
	
	var edit = LineEdit.new()
	edit.text = str(edge_data.weight)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(50, 30)
	
	var mid_point = (edge_data.src.pos + edge_data.dst.pos) / 2.0
	edit.global_position = mid_point - (Vector2(50, 30) / 2.0)

	get_tree().root.add_child(edit)
	Globals.active_weight_editor = edit
	
	edit.grab_focus()
	edit.select_all()
	edit.text_submitted.connect(_on_weight_submitted.bind(edit))

## Submits the new weight to the CommandManager and cleans up the UI.
func _on_weight_submitted(new_text: String, _edit_node: LineEdit) -> void:
	if new_text.is_valid_int() or new_text.is_valid_float():
		var cmd = ChangeEdgeWeightCommand.new(edge_data, new_text.to_int())
		CommandManager.execute(cmd)
	
	if Globals.active_weight_editor:
		Globals.active_weight_editor.queue_free()
		Globals.active_weight_editor = null

## Handles the vanished signal from the data layer.
func _on_edge_vanished(_killer: Vertex) -> void:
	# TBD: Optional: play a fade-out animation before queue_free!
	queue_free()