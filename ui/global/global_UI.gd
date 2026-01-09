extends CanvasLayer

@onready var graph_controller: GraphController = $"../GraphController"

const SELECTION_RECT_BLUEPRINT = preload("res://ui/selection/selection_rect_view.tscn")

const LOG_TAG = "GLOBAL_UI"

var _is_holding = false
var _press_timer = 0.0
var _monitoring_input = false # To prevent checking timer when not clicking
var selection_rect: UISelectionRect


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Process input when in SELECTION mode
	
	if _monitoring_input:
		_press_timer += delta

		if _press_timer >= Globals.HOLD_THRESHOLD and not _is_holding:
			_is_holding = true
			_on_hold_start()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
		event.button_index == MOUSE_BUTTON_LEFT \
		and Globals.current_state == Globals.State.SELECTION:
		if event.is_pressed():
			# Mouse down, start timer
			_monitoring_input = true
			_press_timer = 0.0
			_is_holding = false

			# To provide snappy feedback, we assume the user is mass-selecting. Even if it's just a click.
			if not graph_controller.is_vertex_collision(event.global_position):
				_start_drag()

		elif not event.is_pressed():
			# Mouse up
			_monitoring_input = false

			if _is_holding:
				# Hold let go
				_on_hold_end()
			else:
				# Let go before threshold - click
				_on_click()

	if event is InputEventKey and event.is_pressed():
		_handle_keyboard(event)

func _start_drag():
	# The selection rectangle updates Globals.selection_rectangle independently
	selection_rect = SELECTION_RECT_BLUEPRINT.instantiate()
	add_child(selection_rect)

func _on_click():
	GLogger.debug("User clicked.", LOG_TAG)
	# It was a click! Stop selection
	remove_child(selection_rect)

	if selection_rect != null:
		selection_rect.queue_free()
		selection_rect = null


func _on_hold_start():
	GLogger.debug("User hold start.", LOG_TAG)

	Globals.is_mass_select = true

func _on_hold_end():
	GLogger.debug("User hold end.", LOG_TAG)

	if selection_rect != null:
		remove_child(selection_rect)
		selection_rect.queue_free()
		selection_rect = null

	# Resetting selection so other nodes don't highlight anything
	Globals.selection_rectangle = Rect2(Vector2.ZERO,Vector2.ZERO)
	Globals.is_mass_select = false

func _handle_keyboard(event: InputEventKey) -> void:
	# We only want to switch states if it's a "clean" key press (no Ctrl, Shift, or Alt)
	var is_modified = event.shift_pressed or event.alt_pressed or event.is_command_or_control_pressed()
	
	GLogger.debug("Keyboard Clicked.", LOG_TAG)
	
	# If any modifier is held, stop here so we don't switch states 
	# while trying to Copy/Paste/Undo etc.
	if is_modified:
		return
	
	match event.keycode:
		KEY_C:
			Globals.current_state = Globals.State.CREATE
		KEY_A:
			Globals.current_state = Globals.State.ALG
		KEY_S:
			Globals.current_state = Globals.State.SELECTION
		KEY_E:
			Globals.current_state = Globals.State.ERASER


## Should let user stay in current tool after every action
func _on_lock_tool_pressed() -> void:
	pass # Replace with function body.


func _on_drag_pressed() -> void:
	Globals.current_state = Globals.State.SELECTION


func _on_vertex_pressed() -> void:
	Globals.current_state = Globals.State.CREATE


func _on_algorithm_pressed() -> void:
	Globals.current_state = Globals.State.ALG


func _on_eraser_pressed() -> void:
	Globals.current_state = Globals.State.ERASER
