extends Node2D
class_name MathGridBackground

@export var grid_enabled := false
@export var minor_line_color := Color(0.86, 0.87, 0.90, 0.9)
@export var major_line_color := Color(0.72, 0.74, 0.80, 0.9)
@export var minor_grid_step := 44.0
@export var major_line_every := 5
@export var minor_line_width := 1.0
@export var major_line_width := 1.5

const MAX_GRID_LINES := 1200

func _ready() -> void:
	z_index = -100
	z_as_relative = false
	set_process(true)
	queue_redraw()

func set_grid_enabled(enabled: bool) -> void:
	if grid_enabled == enabled:
		return
	grid_enabled = enabled
	queue_redraw()

func _process(_delta: float) -> void:
	if grid_enabled:
		queue_redraw()

func _draw() -> void:
	if not grid_enabled:
		return

	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size
	if camera == null or viewport_size == Vector2.ZERO:
		return

	var zoom := camera.zoom
	var zoom_x := maxf(absf(zoom.x), 0.001)
	var zoom_y := maxf(absf(zoom.y), 0.001)
	var world_size := Vector2(viewport_size.x / zoom_x, viewport_size.y / zoom_y)
	var world_top_left := camera.global_position - (world_size * 0.5)
	var world_bottom_right := camera.global_position + (world_size * 0.5)
	# Expand bounds by one extra cell so edges stay seamless while panning.
	world_top_left -= Vector2(minor_grid_step, minor_grid_step)
	world_bottom_right += Vector2(minor_grid_step, minor_grid_step)

	var step: float = maxf(minor_grid_step, 8.0)
	var start_x: float = floorf(world_top_left.x / step) * step
	var start_y: float = floorf(world_top_left.y / step) * step
	var x_count: int = int(ceili((world_bottom_right.x - start_x) / step)) + 1
	var y_count: int = int(ceili((world_bottom_right.y - start_y) / step)) + 1

	if x_count > MAX_GRID_LINES or y_count > MAX_GRID_LINES:
		return

	for ix in range(x_count):
		var x: float = start_x + (ix * step)
		var index_x := int(round(x / step))
		var is_major_x := major_line_every > 0 and index_x % major_line_every == 0
		var color_x := major_line_color if is_major_x else minor_line_color
		var width_x := major_line_width if is_major_x else minor_line_width
		draw_line(
			Vector2(x, world_top_left.y),
			Vector2(x, world_bottom_right.y),
			color_x,
			width_x,
			true
		)

	for iy in range(y_count):
		var y: float = start_y + (iy * step)
		var index_y := int(round(y / step))
		var is_major_y := major_line_every > 0 and index_y % major_line_every == 0
		var color_y := major_line_color if is_major_y else minor_line_color
		var width_y := major_line_width if is_major_y else minor_line_width
		draw_line(
			Vector2(world_top_left.x, y),
			Vector2(world_bottom_right.x, y),
			color_y,
			width_y,
			true
		)
