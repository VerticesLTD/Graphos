extends MarginContainer

@onready var directed_btn: Button = $PanelContainer/HBoxContainer/Modifiers/DirectedBtn
@onready var weighted_btn: Button = $PanelContainer/HBoxContainer/Modifiers/WeightedBtn

func _ready() -> void:
	# Sync the UI to whatever the Globals are on startup
	directed_btn.button_pressed = Globals.active_strategy is DirectedStrategy
	weighted_btn.button_pressed = Globals.is_weighted_mode
	
	# Connect the signals via code
	directed_btn.toggled.connect(_on_directed_toggled)
	weighted_btn.toggled.connect(_on_weighted_toggled)
	
# --- 2. KEYBOARD SHORTCUTS ---
func _input(event: InputEvent) -> void:
	# Don't forget to add "toggle_direction" (D) and "toggle_weight" (W) in Project Settings -> Input Map!
	if event.is_action_pressed("toggle_direction"):
		# Flipping the UI switch automatically triggers _on_directed_toggled
		directed_btn.button_pressed = !directed_btn.button_pressed
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("toggle_weight"):
		weighted_btn.button_pressed = !weighted_btn.button_pressed
		get_viewport().set_input_as_handled()

# --- 3. TOGGLE LOGIC ---
func _on_directed_toggled(is_on: bool) -> void:
	if is_on:
		Globals.active_strategy = DirectedStrategy.new()
	else:
		Globals.active_strategy = UndirectedStrategy.new()

func _on_weighted_toggled(is_on: bool) -> void:
	Globals.is_weighted_mode = is_on
	
func _on_selection_pressed() -> void:
	Globals.current_state = Globals.State.SELECTION


func _on_create_pressed() -> void:
	Globals.current_state = Globals.State.CREATE


# THESE BUTTONS DO NOT EXIST
# When the app has meaning for these states, they should be added.

func _on_algorithm_pressed() -> void:
	Globals.current_state = Globals.State.ALG


func _on_eraser_pressed() -> void:
	Globals.current_state = Globals.State.ERASER
