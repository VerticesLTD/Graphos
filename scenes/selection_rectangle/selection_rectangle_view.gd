class_name UISelectionRect
extends Node2D

var graph: Graph

var initial_click_position: Vector2
var current_mouse_position: Vector2
var rectangle: Rect2
var initial_click_world_position: Vector2
var current_mouse_world_position: Vector2

func _ready() -> void:
	initial_click_position = get_viewport().get_mouse_position()
	if graph:
		initial_click_world_position = graph.get_global_mouse_position()
	else:
		initial_click_world_position = get_global_mouse_position()

func _process(_delta: float) -> void:
	current_mouse_position = get_viewport().get_mouse_position()
	if graph:
		current_mouse_world_position = graph.get_global_mouse_position()
	else:
		current_mouse_world_position = get_global_mouse_position()

	# Calculate Rect2 and normalize negative sizes using abs()
	rectangle = Rect2(initial_click_position, current_mouse_position - initial_click_position).abs()
	Globals.selection_rectangle = Rect2(initial_click_world_position, current_mouse_world_position - initial_click_world_position).abs()
	queue_redraw()

func _draw() -> void:
	# Draw the semi-transparent fill
	draw_rect(rectangle, Globals.SELECTION_FILL_COLOR, true)

	draw_rect(rectangle, Globals.SELECTION_BORDER_COLOR, false, Globals.SELECTION_BORDER_WIDTH)
