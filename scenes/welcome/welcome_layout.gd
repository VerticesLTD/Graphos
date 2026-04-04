## Vertical placement for the welcome stack vs the math grid (notebook “between lines” feel).
## Preload from welcome_overlay.gd so parse order is guaranteed.
extends RefCounted

## Must match [MathGridBackground.minor_grid_step].
const GRID_MINOR_STEP_WORLD := 44.0

## Fraction of one screen-space minor cell to shift the stack so bands avoid sitting on a grid line.
const OFF_LINE_FRACTION := 0.25


static func nudge_welcome_stack_off_grid_lines(column: Control, camera: Camera2D) -> void:
	if column == null:
		return
	var zoom_y := 1.0 if camera == null else maxf(absf(camera.zoom.y), 0.001)
	var step_px := GRID_MINOR_STEP_WORLD * zoom_y
	var nudge := step_px * OFF_LINE_FRACTION
	column.offset_top += nudge
	column.offset_bottom += nudge
