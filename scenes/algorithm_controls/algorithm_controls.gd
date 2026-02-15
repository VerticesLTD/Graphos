# TODO list:
# 1. Create svgs for the buttons - DONE
# 2. Implement the data section - DONE
# 3. Expose a controlled API to set the data section:
#    API takes an algorithm ENUM and data, then sets the data section according to 
#	 the relevant scene blueprint + data provided.
#	 Also add update_data function.
# 4. Make components grow when menu is resized - DONE

extends MarginContainer
class_name AlgorithmControls

## User clicked step back
signal step_back
## User clicked step forward
signal step_forward
## User clicked stop
signal stop

# The main area
@onready var main_v_box: VBoxContainer = $MainPanel/MainVBox
# The algorithm data scene - This is replace when we set new data
@onready var data_separator: HSeparator = $MainPanel/MainVBox/DataSeparator
@onready var algorithm_data: HBoxContainer = $MainPanel/MainVBox/AlgorithmDataPreset
@onready var progress_separator: HSeparator = $MainPanel/MainVBox/ProgressSeparator
@onready var progress_bar: ProgressBar = $MainPanel/MainVBox/ProgressBar
@onready var progress_padding: Control = $MainPanel/MainVBox/Padding

# Text components
@onready var main_title: Label = $MainPanel/MainVBox/TitleSpace/Title

# Dragging button
@onready var drag_button: TextureButton = $MainPanel/DragIndicator/DragLines

# Available algorithm data layouts
var alg_to_layout: Dictionary = {
		AlgorithmPlayer.ALGORITHMS.BFS : [preload("uid://jgjoys0wtvpl"),"BFS Undirected"],
	}

# Dragging logic
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				_drag_start_pos = get_global_mouse_position()
				_drag_start_size = size
				
			else:
				_dragging = false

	elif event is InputEventMouseMotion and _dragging and not drag_button.button_pressed:
		global_position = get_global_mouse_position() - _drag_offset
	
	elif event is InputEventMouseMotion and _dragging and drag_button.button_pressed:
		var curr_mouse_pos = get_global_mouse_position()
		var diff = curr_mouse_pos - _drag_start_pos
		size = _drag_start_size + diff
		size = size.clamp(custom_minimum_size, custom_minimum_size + Vector2(300,400))

func _on_back_pressed() -> void:
	step_back.emit()

func _on_stop_pressed() -> void:
	stop.emit()

func _on_forward_pressed() -> void:
	step_forward.emit()

## The controls will only display the title and buttons
func set_no_algorithm_data() -> void:
	algorithm_data.visible = false
	data_separator.visible = false

## The controls will not show a progress bar
func set_no_algorithm_progress() -> void:
	progress_bar.visible = false
	progress_padding.visible = false
	progress_separator.visible = false

## Show progress bar in controls.
func set_algorithm_progress_visible() -> void:
	progress_bar.visible = true
	progress_padding.visible = true
	progress_separator.visible = true
	
## Set the progress of the bar to a value between 1-100
func set_algorithm_progress(progress: int) -> void:
	set_algorithm_progress_visible()
	
	# We set progress to at least 8 since less then that messes with borders
	progress = clampi(progress, 8, 100)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(progress_bar,"value",progress,0.2)

func set_data_layout(algorithm: AlgorithmPlayer.ALGORITHMS) -> void:
	algorithm_data.queue_free()

	var result = alg_to_layout.get(algorithm)
	if result == null:
		push_warning("Algorithm provided doesn't have a defined data layout. Consider creating one.")
		return

	var layout = result[0].instantiate()
	var alg_name = result[1]
	
	data_separator.visible = true
	main_v_box.add_child(layout)
	main_v_box.move_child(layout,data_separator.get_index()+1)
	algorithm_data = layout 
	
	main_title.text = alg_name
