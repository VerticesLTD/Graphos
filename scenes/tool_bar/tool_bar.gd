extends MarginContainer

## Narrow viewports only: desktop layouts stay unchanged above this width.
const MOBILE_VIEWPORT_MAX_WIDTH := 768.0
const MOBILE_BOTTOM_MARGIN := 24.0

const MOBILE_TOOL_BTN_SIZE := Vector2(54, 54)
const MOBILE_HBOX_SEP := 24
const MOBILE_ICON_MARGIN := 6
const MOBILE_MODIFIER_FONT := 15

@onready var directed_btn: Button    = $PanelContainer/HBoxContainer/Modifiers/DirectedBtn
@onready var weighted_btn: Button    = $PanelContainer/HBoxContainer/Modifiers/WeightedBtn
@onready var tool_row: HBoxContainer = $PanelContainer/HBoxContainer
@onready var pan_btn: Button         = $PanelContainer/HBoxContainer/Pan
@onready var selection_btn: Button   = $PanelContainer/HBoxContainer/Selection
@onready var create_btn: Button      = $PanelContainer/HBoxContainer/Create
@onready var edge_btn: Button        = $PanelContainer/HBoxContainer/Edge
@onready var eraser_btn: Button      = $PanelContainer/HBoxContainer/Eraser

var _mobile_layout_active := false

var _desktop_margin_top: int
var _desktop_offset_left: float
var _desktop_offset_right: float
var _desktop_offset_top: float
var _desktop_offset_bottom: float
var _desktop_grow_horizontal: Control.GrowDirection
var _desktop_grow_vertical: Control.GrowDirection
var _desktop_tool_row_separation: int
var _desktop_tool_btn_min: Vector2
var _desktop_icon_margin: int
var _desktop_modifier_font: int


func _ready() -> void:
	_cache_desktop_layout()
	# canvas_items stretch keeps the root viewport at base size (e.g. 1280 wide);
	# real narrow screens must use the window / browser width, not viewport rect alone.
	get_window().size_changed.connect(_on_window_or_viewport_resized)

	tool_row.move_child(pan_btn, 0)
	tool_row.move_child(edge_btn, 1)

	# ButtonGroup makes the tool buttons mutually exclusive and prevents
	# re-clicking the active tool from deselecting it.
	var tool_group := ButtonGroup.new()
	pan_btn.button_group       = tool_group
	selection_btn.button_group = tool_group
	create_btn.button_group    = tool_group
	edge_btn.button_group      = tool_group
	eraser_btn.button_group    = tool_group
	_sync_tool_buttons()

	directed_btn.button_pressed = Globals.active_strategy is DirectedStrategy
	weighted_btn.button_pressed = Globals.is_weighted_mode

	directed_btn.toggled.connect(_on_directed_toggled)
	weighted_btn.toggled.connect(_on_weighted_toggled)

	Globals.strategy_changed.connect(_sync_directed_btn)
	Globals.weighted_mode_changed.connect(_sync_weighted_btn)

	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")


func _on_window_or_viewport_resized() -> void:
	_apply_responsive_layout()


func _cache_desktop_layout() -> void:
	_desktop_margin_top = get_theme_constant("margin_top", "MarginContainer")
	_desktop_offset_left = offset_left
	_desktop_offset_right = offset_right
	_desktop_offset_top = offset_top
	_desktop_offset_bottom = offset_bottom
	_desktop_grow_horizontal = grow_horizontal
	_desktop_grow_vertical = grow_vertical
	_desktop_tool_row_separation = tool_row.get_theme_constant("separation", "HBoxContainer")
	_desktop_tool_btn_min = selection_btn.custom_minimum_size
	var icon_margin_root := pan_btn.get_node("MarginContainer") as MarginContainer
	_desktop_icon_margin = icon_margin_root.get_theme_constant("margin_left", "MarginContainer")
	_desktop_modifier_font = directed_btn.get_theme_font_size("font_size", "Button")


## Width used for the mobile breakpoint. With stretch/canvas_items the logical
## viewport stays at the project base width; window size and (on web) innerWidth
## reflect the actual layout width.
func _layout_width_for_breakpoint() -> float:
	var w := float(DisplayServer.window_get_size().x)
	var vp_w := get_viewport().get_visible_rect().size.x
	if w <= 0.0:
		w = vp_w
	else:
		w = minf(w, vp_w)
	if OS.has_feature("web"):
		var inner: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if inner != null:
			var iw := float(inner)
			if iw > 0.0:
				w = minf(w, iw)
	return w


func _is_mobile_viewport() -> bool:
	return _layout_width_for_breakpoint() <= MOBILE_VIEWPORT_MAX_WIDTH


func _apply_responsive_layout() -> void:
	var mobile := _is_mobile_viewport()
	if mobile != _mobile_layout_active:
		if mobile:
			_enter_mobile_layout()
		else:
			_enter_desktop_layout()
		_mobile_layout_active = mobile
	if mobile:
		call_deferred("_snap_mobile_bottom")


func _enter_mobile_layout() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	tool_row.add_theme_constant_override("separation", MOBILE_HBOX_SEP)
	for btn in [pan_btn, selection_btn, create_btn, edge_btn, eraser_btn]:
		btn.custom_minimum_size = MOBILE_TOOL_BTN_SIZE
		var mc := btn.get_node("MarginContainer") as MarginContainer
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			mc.add_theme_constant_override(side, MOBILE_ICON_MARGIN)
	directed_btn.add_theme_font_size_override("font_size", MOBILE_MODIFIER_FONT)
	weighted_btn.add_theme_font_size_override("font_size", MOBILE_MODIFIER_FONT)


func _enter_desktop_layout() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = _desktop_grow_horizontal
	grow_vertical = _desktop_grow_vertical
	offset_left = _desktop_offset_left
	offset_right = _desktop_offset_right
	offset_top = _desktop_offset_top
	offset_bottom = _desktop_offset_bottom
	add_theme_constant_override("margin_top", _desktop_margin_top)
	remove_theme_constant_override("margin_bottom")
	remove_theme_constant_override("margin_left")
	remove_theme_constant_override("margin_right")
	tool_row.add_theme_constant_override("separation", _desktop_tool_row_separation)
	for btn in [pan_btn, selection_btn, create_btn, edge_btn, eraser_btn]:
		btn.custom_minimum_size = _desktop_tool_btn_min
		var mc := btn.get_node("MarginContainer") as MarginContainer
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			mc.add_theme_constant_override(side, _desktop_icon_margin)
	directed_btn.add_theme_font_size_override("font_size", _desktop_modifier_font)
	weighted_btn.add_theme_font_size_override("font_size", _desktop_modifier_font)


func _snap_mobile_bottom() -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(
		roundf(vp.x * 0.5 - size.x * 0.5),
		vp.y - size.y - MOBILE_BOTTOM_MARGIN
	)


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


func _on_edge_pressed() -> void:
	Globals.current_state = Globals.State.EDGE


func _sync_tool_buttons() -> void:
	pan_btn.button_pressed       = Globals.current_state == Globals.State.PAN
	selection_btn.button_pressed = Globals.current_state == Globals.State.SELECTION
	create_btn.button_pressed    = Globals.current_state == Globals.State.CREATE
	edge_btn.button_pressed      = Globals.current_state == Globals.State.EDGE
	eraser_btn.button_pressed    = Globals.current_state == Globals.State.ERASER


## Blocks signals during sync to prevent re-entrant toggle loops.
func _sync_directed_btn() -> void:
	directed_btn.set_block_signals(true)
	directed_btn.button_pressed = Globals.active_strategy is DirectedStrategy
	directed_btn.set_block_signals(false)


func _sync_weighted_btn() -> void:
	weighted_btn.set_block_signals(true)
	weighted_btn.button_pressed = Globals.is_weighted_mode
	weighted_btn.set_block_signals(false)
