extends Node2D
class_name UISelectionRect

var initial_click_position: Vector2
var current_mouse_position: Vector2
var rectangle: Rect2

func _ready() -> void:
	initial_click_position = get_global_mouse_position()

func _process(_delta: float) -> void:
	current_mouse_position = get_global_mouse_position()
	# Calculate Rect2 and normalize negative sizes using abs()
	rectangle = Rect2(initial_click_position, current_mouse_position - initial_click_position).abs()
	Globals.selection_rectangle = rectangle
	queue_redraw()

func _draw() -> void:
	# Draw the semi-transparent fill
	draw_rect(rectangle, Globals.SELECTION_FILL_COLOR, true)

	draw_rect(rectangle, Globals.SELECTION_BORDER_COLOR, false, Globals.SELECTION_BORDER_WIDTH)
