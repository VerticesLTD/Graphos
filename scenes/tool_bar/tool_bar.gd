extends MarginContainer

@onready var directed_btn: Button    = $PanelContainer/HBoxContainer/Modifiers/DirectedBtn
@onready var weighted_btn: Button    = $PanelContainer/HBoxContainer/Modifiers/WeightedBtn
@onready var tool_row: HBoxContainer = $PanelContainer/HBoxContainer
@onready var pan_btn: Button         = $PanelContainer/HBoxContainer/Pan
@onready var selection_btn: Button   = $PanelContainer/HBoxContainer/Selection
@onready var create_btn: Button      = $PanelContainer/HBoxContainer/Create


func _ready() -> void:
	tool_row.move_child(pan_btn, 0)

	# ButtonGroup makes the tool buttons mutually exclusive and prevents
	# re-clicking the active tool from deselecting it.
	var tool_group := ButtonGroup.new()
	pan_btn.button_group       = tool_group
	selection_btn.button_group = tool_group
	create_btn.button_group    = tool_group
	_sync_tool_buttons()

	directed_btn.button_pressed = Globals.active_strategy is DirectedStrategy
	weighted_btn.button_pressed = Globals.is_weighted_mode

	directed_btn.toggled.connect(_on_directed_toggled)
	weighted_btn.toggled.connect(_on_weighted_toggled)

	Globals.strategy_changed.connect(_sync_directed_btn)
	Globals.weighted_mode_changed.connect(_sync_weighted_btn)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_direction"):
		directed_btn.button_pressed = !directed_btn.button_pressed
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("toggle_weight"):
		weighted_btn.button_pressed = !weighted_btn.button_pressed
		get_viewport().set_input_as_handled()


func _on_directed_toggled(is_on: bool) -> void:
	if is_on:
		Globals.active_strategy = DirectedStrategy.new()
	else:
		Globals.active_strategy = UndirectedStrategy.new()


func _on_weighted_toggled(is_on: bool) -> void:
	Globals.is_weighted_mode = is_on


func _on_selection_pressed() -> void:
	Globals.current_state = Globals.State.SELECTION


func _on_pan_pressed() -> void:
	Globals.current_state = Globals.State.PAN


func _on_create_pressed() -> void:
	Globals.current_state = Globals.State.CREATE


func _sync_tool_buttons() -> void:
	pan_btn.button_pressed       = Globals.current_state == Globals.State.PAN
	selection_btn.button_pressed = Globals.current_state == Globals.State.SELECTION
	create_btn.button_pressed    = Globals.current_state == Globals.State.CREATE


## Blocks signals during sync to prevent re-entrant toggle loops.
func _sync_directed_btn() -> void:
	directed_btn.set_block_signals(true)
	directed_btn.button_pressed = Globals.active_strategy is DirectedStrategy
	directed_btn.set_block_signals(false)


func _sync_weighted_btn() -> void:
	weighted_btn.set_block_signals(true)
	weighted_btn.button_pressed = Globals.is_weighted_mode
	weighted_btn.set_block_signals(false)
