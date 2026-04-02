## Floating Templates control (top-right): compact panel matching main toolbar chrome.
extends CanvasLayer

const FALLBACK_TILE_ICON: Texture2D = preload("res://assets/icons/create_tool_icon.svg")
const TRIGGER_TOOLBAR_ICON: Texture2D = preload("res://assets/icons/templates_toolbar.svg")
const LIVE_THUMB_SCENE: PackedScene = preload("res://scenes/presets/preset_live_thumbnail.tscn")

const STYLE_BTN_NORMAL = preload("res://scenes/tool_bar/button_normal.tres")
const STYLE_BTN_HOVER = preload("res://scenes/tool_bar/button_hover.tres")

## Scroll area sized so ~3 tile rows + label fit without clipping the bottom row.
const POPUP_WIDTH := 328
const POPUP_HEIGHT := 380

@export var graph_controller_path: NodePath = ^"../GraphController"

@onready var _trigger: Button = $Margin/TriggerPanel/TemplatesButton
@onready var _popup: Popup = $ChooserPopup

var _graph_controller: GraphController


func _ready() -> void:
	_graph_controller = get_node_or_null(graph_controller_path) as GraphController
	if _graph_controller == null:
		push_warning("PresetPicker: GraphController not found at %s" % str(graph_controller_path))
	_style_trigger_button()
	_trigger.pressed.connect(_on_trigger_pressed)
	_popup.visibility_changed.connect(_on_popup_visibility_changed)
	_build_grid()


func _style_trigger_button() -> void:
	## Match toolbar tool row height (52px) inside the same panel style; shrink-wrap panel (no stretch inside slot).
	var pad := 8.0
	var normal_sb: StyleBoxFlat = STYLE_BTN_NORMAL.duplicate() as StyleBoxFlat
	normal_sb.content_margin_left = pad
	normal_sb.content_margin_right = pad
	normal_sb.content_margin_top = 2
	normal_sb.content_margin_bottom = 2
	var hover_sb: StyleBoxFlat = STYLE_BTN_HOVER.duplicate() as StyleBoxFlat
	hover_sb.content_margin_left = pad
	hover_sb.content_margin_right = pad
	hover_sb.content_margin_top = 2
	hover_sb.content_margin_bottom = 2

	_trigger.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_trigger.icon = TRIGGER_TOOLBAR_ICON
	_trigger.text = "Templates"
	_trigger.custom_minimum_size = Vector2(104, 52)
	_trigger.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_trigger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tp: PanelContainer = _trigger.get_parent() as PanelContainer
	if tp:
		tp.size_flags_horizontal = Control.SIZE_SHRINK_END
		tp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trigger.focus_mode = Control.FOCUS_NONE
	_trigger.flat = false
	_trigger.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_trigger.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_trigger.expand_icon = false
	_trigger.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_trigger.add_theme_constant_override("h_separation", 6)
	_trigger.add_theme_constant_override("icon_max_width", 20)
	_trigger.add_theme_stylebox_override("normal", normal_sb)
	_trigger.add_theme_stylebox_override("hover", hover_sb)
	_trigger.add_theme_stylebox_override("pressed", hover_sb)
	_trigger.add_theme_stylebox_override("focus", hover_sb)
	_trigger.add_theme_font_size_override("font_size", 12)
	_trigger.add_theme_color_override("font_color", Color(0.118, 0.118, 0.18))
	_trigger.add_theme_color_override("font_hover_color", Color(0.263, 0.38, 0.933))
	_trigger.add_theme_color_override("font_pressed_color", Color(0.263, 0.38, 0.933))
	_trigger.add_theme_color_override("font_focus_color", Color(0.263, 0.38, 0.933))


func _build_grid() -> void:
	var grid: GridContainer = $ChooserPopup/PanelRoot/Margin/Scroll/Grid
	for c in grid.get_children():
		c.queue_free()
	for entry in GraphPresetCatalog.built_in_entries():
		var data_path: String = entry.get("data_path", "")
		var label: String = entry.get("display_name", "Preset")
		var kind: String = str(entry.get("thumbnail_kind", "live"))
		var tile: Control
		if kind == "static":
			var pth: String = entry.get("thumbnail_path", "")
			var tex: Texture2D = _load_thumbnail(pth)
			tile = _make_preset_tile(label, data_path, tex, null)
		else:
			var live: PresetLiveThumbnail = LIVE_THUMB_SCENE.instantiate() as PresetLiveThumbnail
			live.configure(data_path)
			tile = _make_preset_tile(label, data_path, null, live)
		grid.add_child(tile)


func _load_thumbnail(path: String) -> Texture2D:
	if path.is_empty():
		return FALLBACK_TILE_ICON
	var res = load(path)
	if res is Texture2D:
		return res as Texture2D
	return FALLBACK_TILE_ICON


func _make_preset_tile(display_name: String, json_path: String, tex: Texture2D, live: PresetLiveThumbnail) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(88, 96)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.99, 1.0, 1.0)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.88, 0.88, 0.89)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 4
	normal.content_margin_bottom = 3
	var hover_sb: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover_sb.bg_color = Color(0.906, 0.922, 0.988)
	hover_sb.border_color = Color(0.263, 0.38, 0.933, 0.38)

	root.add_theme_stylebox_override("panel", normal)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cap := Label.new()
	cap.text = display_name
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.118, 0.118, 0.18))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(0, 22)

	if live != null:
		live.size_flags_vertical = Control.SIZE_EXPAND_FILL
		live.custom_minimum_size = Vector2(0, 58)
		vb.add_child(cap)
		vb.add_child(live)
	else:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 58)
		tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(cap)
		vb.add_child(tr)

	root.add_child(vb)

	root.mouse_entered.connect(func(): root.add_theme_stylebox_override("panel", hover_sb))
	root.mouse_exited.connect(func(): root.add_theme_stylebox_override("panel", normal))
	root.gui_input.connect(func(ev: InputEvent): _on_tile_gui_input(ev, json_path))

	return root


func _on_tile_gui_input(ev: InputEvent, json_path: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_on_preset_chosen(json_path)


func _on_preset_chosen(json_path: String) -> void:
	_popup.hide()
	if _graph_controller:
		_graph_controller.insert_preset_from_json_path(json_path)


func _on_trigger_pressed() -> void:
	var gp := _trigger.get_global_rect()
	_popup.size = Vector2i(POPUP_WIDTH, POPUP_HEIGHT)
	var x := int(gp.position.x + gp.size.x - _popup.size.x)
	var y := int(gp.position.y + gp.size.y + 8)
	var vp := get_viewport().get_visible_rect().size
	x = clampi(x, 8, int(vp.x) - _popup.size.x - 8)
	y = clampi(y, 8, int(vp.y) - _popup.size.y - 8)
	_popup.position = Vector2i(x, y)
	_popup.popup()


func _on_popup_visibility_changed() -> void:
	if _popup.visible:
		get_tree().call_group("preset_live_thumbnails", "refresh")
