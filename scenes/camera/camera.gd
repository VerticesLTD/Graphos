extends Camera2D

## Fired after zoom or pan so the scene can persist the view.
signal view_changed

@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0

var _target_zoom: float = 1.0
var _is_dragging: bool = false
var _pan_mode_enabled: bool = false
var _last_pan_mode_enabled: bool = false
var _applied_cursor_state := -1

# Mobile touch zoom
var _last_pinch_distance: float

const CURSOR_STATE_ARROW := 0
const CURSOR_STATE_PAN_IDLE := 1
const CURSOR_STATE_PAN_DRAG := 2

const PAN_HAND_CURSOR: Texture2D = preload("res://assets/icons/hand.svg")
const PAN_GRAB_CURSOR: Texture2D = preload("res://assets/icons/hand-grabbing.svg")


func _process(_delta: float) -> void:
	_pan_mode_enabled = Globals.current_state == Globals.State.PAN
	if _pan_mode_enabled != _last_pan_mode_enabled:
		if not _pan_mode_enabled:
			_is_dragging = false
		_last_pan_mode_enabled = _pan_mode_enabled
		_update_cursor_shape()

	if _pan_mode_enabled or _is_dragging:
		_update_cursor_shape()


func _unhandled_input(event: InputEvent) -> void:
	if AppInputPolicy.is_text_field_focused():
		return

	if event is InputEventMagnifyGesture:
		_zoom_camera(event.factor, true)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			Globals.active_touches[event.index] = event.position
		else:
			Globals.active_touches.erase(event.position)
		
		if Globals.active_touches.size() == 2:
			var touch_keys: Array = Globals.active_touches.keys()
			_last_pinch_distance = Globals.active_touches[touch_keys[0]].distance_to(Globals.active_touches[touch_keys[1]])
		else:
			_last_pinch_distance = 0.0
		return

	if event is InputEventScreenDrag and not Globals.current_state == Globals.State.PAN:
		Globals.active_touches[event.index] = event.position

		if Globals.active_touches.size() == 2 and _last_pinch_distance > 0.0:
			var touch_keys: Array = Globals.active_touches.keys()
			var current_distance: float = Globals.active_touches[touch_keys[0]].distance_to(Globals.active_touches[touch_keys[1]])

			# 1.0 deadzone to prevent jitters
			if current_distance > 0.0 and abs(current_distance - _last_pinch_distance) > 1.0:
				var zoom_factor: float = current_distance / _last_pinch_distance 
				_zoom_camera(zoom_factor,false)
				_last_pinch_distance = current_distance
				get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.is_command_or_control_pressed():
		return

	if not event.pressed:
		return

	var pk: int = event.physical_keycode
	# Ctrl+=, numpad +, or a dedicated + key; Ctrl+- or numpad -.
	var zoom_in: bool = pk == KEY_EQUAL or pk == KEY_KP_ADD or pk == KEY_PLUS
	var zoom_out: bool = pk == KEY_MINUS or pk == KEY_KP_SUBTRACT
	if zoom_in:
		_zoom_camera(1.0 + zoom_speed, false)
		get_viewport().set_input_as_handled()
	elif zoom_out:
		_zoom_camera(1.0 - zoom_speed, false)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var wheel: bool = (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		)
		if wheel and AppInputPolicy.is_pointer_over_blocking_control():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 + zoom_speed, true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 - zoom_speed, true)

		var is_middle: bool = event.button_index == MOUSE_BUTTON_MIDDLE
		var is_left_pan: bool = event.button_index == MOUSE_BUTTON_LEFT and _pan_mode_enabled
		if (is_middle or is_left_pan) and event.pressed and AppInputPolicy.is_pointer_over_blocking_control():
			return
		if is_middle or is_left_pan:
			_is_dragging = event.pressed
			if not event.pressed:
				_is_dragging = false
				view_changed.emit()
			_update_cursor_shape()

	if event is InputEventScreenDrag and _is_dragging:
		position += event.relative / zoom.x
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging and not Globals.is_running_on_mobile:
		position -= event.relative / zoom.x
		_update_cursor_shape()

## factor multiplies the current zoom; it is clamped to [min_zoom, max_zoom].
## If center_on_mouse is true, the point under the cursor stays fixed (wheel).
## If false, the viewport center stays fixed (Ctrl+/Ctrl-).
func _zoom_camera(factor: float, center_on_mouse: bool) -> void:
	var anchor_before: Vector2 = (
		get_global_mouse_position() if center_on_mouse else get_screen_center_position()
	)

	_target_zoom = clamp(_target_zoom * factor, min_zoom, max_zoom)
	zoom = Vector2(_target_zoom, _target_zoom)

	var anchor_after: Vector2 = (
		get_global_mouse_position() if center_on_mouse else get_screen_center_position()
	)
	position += anchor_before - anchor_after
	view_changed.emit()


func toggle_pan_mode(pan_enabled: bool) -> void:
	_pan_mode_enabled = pan_enabled
	_update_cursor_shape()


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
		Input.set_custom_mouse_cursor(PAN_GRAB_CURSOR, Input.CURSOR_ARROW, Vector2(8, 8))
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	elif _pan_mode_enabled:
		Input.set_custom_mouse_cursor(PAN_HAND_CURSOR, Input.CURSOR_ARROW, Vector2(8, 8))
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
