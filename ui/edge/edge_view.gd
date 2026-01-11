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

func _setup_detection_area() -> void:
	# Assumes edge_data exists
	var pos1 = edge_data.src.pos
	var pos2  = edge_data.dst.pos
	var width = Globals.EDGE_WIDTH + MOUSE_DETECT_SENSITIVITY

	var length: float = pos1.distance_to(pos2)
	var midpoint: Vector2 = (pos1 + pos2) / 2.0
	var rotation_angle: float = pos1.angle_to_point(pos2)

	mouse_detection_area.position = midpoint
	mouse_detection_area.rotation = rotation_angle

	if not collision_shape.shape is RectangleShape2D:
		collision_shape.shape = RectangleShape2D.new()
	
	var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D

	shape.size = Vector2(length, width)


func refresh() -> void:
	# Making sure the detection area still matches what we are drawing
	_setup_detection_area()

	queue_redraw()

func _draw() -> void:
	# Stop if the brain or its endpoints are missing.
	if not edge_data or not edge_data.src or not edge_data.dst:
		return

	if is_hovered:
		draw_line(edge_data.src.pos, edge_data.dst.pos, draw_color_hovered, draw_width_hovered)
	else:
		draw_line(edge_data.src.pos, edge_data.dst.pos, edge_data.color, Globals.EDGE_WIDTH)


func _on_mouse_entered() -> void:
	is_hovered = true
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
	# is_hovered will be set by the _tween!
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
