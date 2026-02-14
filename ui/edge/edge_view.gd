extends Node2D
class_name UIEdgeView
## This script controls the "Body" of a connection between two vertices.
## It draws a line between the source and destination provided by the Brain.

## Higher value = Mouse detected from further away
const MOUSE_DETECT_SENSITIVITY = 5.0

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var edge_data: Edge 

@onready var mouse_detection_area: Area2D = $MouseDetectionArea
@onready var collision_shape: CollisionShape2D = $MouseDetectionArea/CollisionShape2D

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
		_setup_detection_area()

		# 1. Listen for edge updates (like color changes)
		edge_data.state_changed.connect(refresh)
		
		# 2. Listen for "die" commands and clear
		edge_data.vanished.connect(queue_free)		
		
		# Initial draw
		refresh()		
	else:
		# If there's no edge, delete.
		queue_free()

func _process(_delta: float) -> void:
	# Redraw every frame is needed for animations.
	# Could perhaps be optimized
	queue_redraw()

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
	# Stop if the brain or its endpoints are missing.
	if not edge_data or not edge_data.src or not edge_data.dst:
		return
	var pos1 = edge_data.src.pos
	var pos2 = edge_data.dst.pos

	var draw_positions = _get_visual_start_end(pos1,pos2)
	var visual_start = draw_positions[0]
	var visual_end = draw_positions[1]

	if is_hovered:
		draw_line(visual_start, visual_end, draw_color_hovered, draw_width_hovered)
	else:
		draw_line(visual_start, visual_end, edge_data.color, Globals.EDGE_WIDTH)
		
	# Flow animation (growing highlight)
	if highlight_progress > 0.0:
		_draw_flow_animation_line(visual_start,visual_end)

func _draw_flow_animation_line(start_pos: Vector2, end_pos: Vector2) -> void:
	if not highlight_direction:
		var temp = start_pos
		start_pos = end_pos
		end_pos = temp
		
	var highlight_end = start_pos.lerp(end_pos, highlight_progress)
	draw_line(start_pos, highlight_end, Globals.EDGE_HOVER_COLOR, draw_width_hovered)

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


# --- FLOW ANIMATION --
# This is a separate animation that "grows" a highlight from src to dst.
# Originally meant to be used when mass selecting, I couldn't figure out how
# to get the directions right. Keeping it here for future use.

var highlight_progress: float = 0.0
var highlight_direction: bool = true
var _flow_tween: Tween

func start_flow_animation(from_src_to_dst: bool = true) -> void:
	highlight_direction = from_src_to_dst
	if _flow_tween: _flow_tween.kill()
	_flow_tween = create_tween()
	
	_flow_tween.tween_property(self, "highlight_progress", 1.0, Globals.EDGE_FLOW_TWEEN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_flow_animation() -> void:
	if _flow_tween: _flow_tween.kill()
	_flow_tween = create_tween()
	
	_flow_tween.tween_property(self, "highlight_progress", 0.0, Globals.EDGE_FLOW_TWEEN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
