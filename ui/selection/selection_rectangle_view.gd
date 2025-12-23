extends Node2D
class_name UISelectionRect

const WIDTH = 1.0
const REC_COLOR = Color.BLUE

## 2 Points to draw the rectangle by
var initial_click_position : Vector2
var current_mouse_position : Vector2
var rectangle: Rect2

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	# Updating mouse position
	current_mouse_position = get_global_mouse_position()

	# Calculating selection rectangle
	rectangle = Rect2(initial_click_position,abs(current_mouse_position - initial_click_position))

	queue_redraw()

func _draw() -> void:
	draw_rect(rectangle,REC_COLOR,false,WIDTH,true)
