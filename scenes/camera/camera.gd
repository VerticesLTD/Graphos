extends Camera2D

# --- CONFIGURATION ---
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0
@export var smooth_speed: float = 15.0

# State
var _target_zoom: float = 1.0
var _is_dragging: bool = false
var _pan_mode_enabled: bool = false 
var _last_pan_mode_enabled: bool = false
var _applied_cursor_state := -1

const CURSOR_STATE_ARROW := 0
const CURSOR_STATE_PAN_IDLE := 1
const CURSOR_STATE_PAN_DRAG := 2

const PAN_HAND_CURSOR: Texture2D = preload("res://assets/icons/hand.svg")
const PAN_GRAB_CURSOR: Texture2D = preload("res://assets/icons/hand-grabbing.svg")

func _process(_delta: float) -> void:
	# Pan mode is driven by global tool state.
	_pan_mode_enabled = Globals.current_state == Globals.State.PAN
	if _pan_mode_enabled != _last_pan_mode_enabled:
		if not _pan_mode_enabled:
			_is_dragging = false
		_last_pan_mode_enabled = _pan_mode_enabled
		_update_cursor_shape()

	# Enforce cursor while panning/dragging so other hover handlers cannot override it.
	if _pan_mode_enabled or _is_dragging:
		_update_cursor_shape()

# Input handling
func _input(event: InputEvent) -> void:
	# Handle Zoom (Mouse Wheel)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 - zoom_speed)

		# Handle Drag Start/Stop
		# Middle Click always drags. 
		# Left Click only drags if Pan Mode is enabled.
		var is_middle_click = event.button_index == MOUSE_BUTTON_MIDDLE
		var is_left_click_pan = event.button_index == MOUSE_BUTTON_LEFT and _pan_mode_enabled
		
		if is_middle_click or is_left_click_pan:
			_is_dragging = event.pressed
			if not event.pressed:
				# Safety reset when drag ends.
				_is_dragging = false
			# UPDATE: Trigger the cursor change immediately
			_update_cursor_shape()

	# Handle Drag Motion
	if event is InputEventMouseMotion and _is_dragging:
		# Divide by zoom so the 'relative' pixels match the world coordinates
		position -= event.relative / zoom.x
		_update_cursor_shape()

# Zoom the camera by a factor
func _zoom_camera(factor: float) -> void:
	# Store the mouse position in the world BEFORE we zoom
	var mouse_pos_before = get_global_mouse_position()
	
	# Calculate the new zoom level
	_target_zoom = clamp(_target_zoom * factor, min_zoom, max_zoom)
	
	# Update the actual zoom property
	# (In a 'smooth' version, we do the correction after the lerp in _process)
	zoom = Vector2(_target_zoom, _target_zoom)
	
	# Store the mouse position in the world AFTER we zoom
	var mouse_pos_after = get_global_mouse_position()
	
	# COrrection: Shifting the camera by the difference keeps the cursor pinned to the same spot.
	position += (mouse_pos_before - mouse_pos_after)
 
func toggle_pan_mode(enabled: bool) -> void:
	_pan_mode_enabled = enabled
	_update_cursor_shape()

# Internal helper to handle the cursor logic
func _update_cursor_shape() -> void:
	var target_state := CURSOR_STATE_ARROW
	if _is_dragging:
		target_state = CURSOR_STATE_PAN_DRAG
	elif _pan_mode_enabled:
		target_state = CURSOR_STATE_PAN_IDLE

	if target_state == _applied_cursor_state:
		return
	_applied_cursor_state = target_state

	if _is_dragging:
		# Closed hand while panning.
		Input.set_custom_mouse_cursor(PAN_GRAB_CURSOR, Input.CURSOR_ARROW, Vector2(8, 8))
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	elif _pan_mode_enabled:
		# Open hand while pan mode is enabled.
		Input.set_custom_mouse_cursor(PAN_HAND_CURSOR, Input.CURSOR_ARROW, Vector2(8, 8))
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	else:
		# Normal arrow otherwise.
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
