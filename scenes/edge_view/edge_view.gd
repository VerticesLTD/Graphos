extends Node2D
class_name UIEdgeView
## This script controls the "Body" of a connection between two vertices.
## It draws a line between the source and destination provided by the Brain.

## Affects the gap for displaying the edge weight
var weight_gap: float = 30.0

## Higher value = Mouse detected from further away
const MOUSE_DETECT_SENSITIVITY = 9.0

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var edge_data: Edge 

@onready var mouse_detection_area: Area2D = $MouseDetectionArea
@onready var collision_shape: CollisionShape2D = $MouseDetectionArea/CollisionShape2D
@onready var line_1: Line2D = $Line1
@onready var line_2: Line2D = $Line2
@onready var weight_label: Label = $Weight

# Drawing properties - Will be tweened for animations
var draw_width_hovered = Globals.EDGE_WIDTH
var draw_color_hovered = Globals.EDGE_COLOR

# Animations
var is_hovered: bool = false
var is_manual_hover: bool = false
var _tween: Tween


## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if edge_data:
		weight_label.text = str(edge_data.weight)

		_setup_detection_area()

		# Listen for edge updates (like color changes)
		edge_data.state_changed.connect(refresh)
		
		# Listen for "die" commands and clear
		edge_data.vanished.connect(queue_free)
		
		# Detect edge refractoring
		mouse_detection_area.input_event.connect(_on_mouse_detection_area_input_event)		
		
		# Initial draw
		refresh()		
	else:
		# If there's no edge, delete.
		queue_free()

func _process(_delta: float) -> void:
	_setup_lines_and_weight()

	weight_label.text = str(edge_data.weight)
	# Making sure there is enough space to display the weight
	if weight_label.text.length() >= 3:
		weight_gap = 43.0 # Just enough for -999
	else:
		weight_gap = 30.0
	
	# Making the edge's width affected by the weight
	var width_by_weight = clampf(Globals.EDGE_WIDTH * edge_data.weight / 5, 5.0, 15.0)

	if is_hovered:
		line_1.default_color = draw_color_hovered
		line_2.default_color = draw_color_hovered
		line_1.width = max(draw_width_hovered, width_by_weight)
		line_2.width = max(draw_width_hovered, width_by_weight)
	else:
		line_1.default_color = edge_data.color
		line_2.default_color = edge_data.color
		line_1.width = width_by_weight
		line_2.width = width_by_weight

func _setup_lines_and_weight() -> void:
	# Geometry shananigens for calculating the gap location
	var pos1 = edge_data.src.pos
	var pos2 = edge_data.dst.pos
	var mid_point = pos1.lerp(pos2,0.5)
	var direction = (pos2-pos1).normalized()
	var offset = direction * (weight_gap / 2.0)
	var length = pos1.distance_to(pos2)

	var line_1_end = mid_point - offset
	var line_2_start = mid_point + offset

	# We only draw the gap+weight if there is enough space for it
	if length > (weight_gap * 3):
		weight_label.visible = true
		_update_weight_label_transform()

		line_1.clear_points()
		line_2.clear_points()
		line_1.add_point(pos1)
		line_1.add_point(line_1_end)
		line_2.add_point(line_2_start)
		line_2.add_point(pos2)
	else:
		weight_label.visible = false
		line_1.clear_points()
		line_2.clear_points()
		line_1.add_point(pos1)
		line_1.add_point(pos2)
	
func _update_weight_label_transform() -> void:
	# Geometry shananigens to place the text in the gap
	var pos1 = edge_data.src.pos
	var pos2 = edge_data.dst.pos
	var mid_point = (pos1 + pos2) / 2.0
	var direction = pos2-pos1
	var angle = direction.angle()

	weight_label.pivot_offset = weight_label.size / 2.0
	weight_label.position = mid_point - (weight_label.size / 2.0)

	# Making sure the text is not upside down
	if abs(angle) > PI / 2:
		angle += PI

	weight_label.rotation = angle

func _should_display_weight() -> bool:
	return true	

## Draws the edge's mouse detection area accurately to how it is drawn.
func _setup_detection_area() -> void:
	# Assumes edge_data exists
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

## Calculates exactly where in the vertex the edge should start.
## This makes the edge not be "below" the vertex, which causes some
## mouse detection issues.
func _get_visual_start_end(pos1: Vector2, pos2: Vector2) -> Array[Vector2]:
	var direction = pos1.direction_to(pos2)

	var visual_start = pos1 + (direction * Globals.VERTEX_RADIUS)
	var visual_end = pos2 - (direction * Globals.VERTEX_RADIUS)

	return [visual_start,visual_end]


func refresh() -> void:
	# Making sure the detection area still matches what we are drawing
	_setup_detection_area()

	queue_redraw()

func _draw() -> void:
	return


func _on_mouse_entered() -> void:
	is_hovered = true
	_start_hover_animation()

## This function is used when external forces demand animation to start
func manual_hover_start() -> void:
	is_hovered = true
	is_manual_hover = true
	_start_hover_animation()

func _start_hover_animation() -> void:
	# Stop prev animation if still running
	if _tween: _tween.kill()
	_tween = create_tween()

	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		self,
		"draw_width_hovered",
		Globals.EDGE_WIDTH * Globals.EDGE_HOVER_SCALE,
		Globals.EDGE_TWEEN_TIME
	)
	_tween.tween_property(
		self,
		"draw_color_hovered",
		Globals.EDGE_HOVER_COLOR,	
		Globals.EDGE_TWEEN_TIME
	)


func _on_mouse_exited() -> void:
	# Hover was manually set, we don't want to stop it
	if not is_hovered or is_manual_hover:
		return

	# is_hovered will be set by the _tween!
	_stop_hover_animation()

## This function is used when external forces demand animation to stop
func manual_hover_stop() -> void:
	is_manual_hover = false
	_stop_hover_animation()

func _stop_hover_animation() -> void:
	# Stop previous animation if running
	if _tween: _tween.kill()
	_tween = create_tween()

	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		self,
		"draw_width_hovered",
		Globals.EDGE_WIDTH,
		Globals.EDGE_TWEEN_TIME
	)
	_tween.tween_property(
		self,
		"draw_color_hovered",
		edge_data.color,	
		Globals.VERTEX_TWEEN_TIME
	)
	# Set is hovered to false when finished
	_tween.chain().tween_callback(func(): is_hovered = false)
	# Prevents some bug with chaining color
	_tween.chain().tween_callback(func(): draw_color_hovered = Globals.VERTEX_COLOR)


## Detect double click
func _on_mouse_detection_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_spawn_weight_editor()

## Edit the edge's weight
func _spawn_weight_editor() -> void:
	# Clear old edit line
	if Globals.active_weight_editor:
		Globals.active_weight_editor.queue_free()
	
	# Create the new edit line
	var edit = LineEdit.new()
	edit.text = str(edge_data.weight)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(50, 30)
	
	var mid_point = (edge_data.src.pos + edge_data.dst.pos) / 2.0
	edit.global_position = mid_point - (Vector2(50, 30) / 2.0)

	# Attaches the box to the top of the game
	get_tree().root.add_child(edit)
	Globals.active_weight_editor = edit
	
	# Instantiate the cursor and text selection
	edit.grab_focus()
	edit.select_all()

	edit.text_submitted.connect(_on_weight_submitted.bind(edit))

func _on_weight_submitted(new_text: String, _edit_node: LineEdit) -> void:
	if new_text.is_valid_int() or new_text.is_valid_float():
		var cmd = ChangeEdgeWeightCommand.new(edge_data, new_text.to_int())
		CommandManager.execute(cmd)
	
	# 3. Clean up globally
	if Globals.active_weight_editor:
		Globals.active_weight_editor.queue_free()
		Globals.active_weight_editor = null
