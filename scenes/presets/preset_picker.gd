## Floating top-right panel: combined Share + Presets trigger in one bar.
extends CanvasLayer

const FALLBACK_TILE_ICON: Texture2D = preload("res://assets/icons/create_tool_icon.svg")
const TRIGGER_TOOLBAR_ICON: Texture2D = preload("res://assets/icons/presets_toolbar.svg")
const SHARE_TOOLBAR_ICON: Texture2D = preload("res://assets/icons/share_icon.svg")
const LIVE_THUMB_SCENE: PackedScene = preload("res://scenes/presets/preset_live_thumbnail.tscn")

const STYLE_BTN_NORMAL = preload("res://scenes/tool_bar/button_normal.tres")
const STYLE_BTN_HOVER = preload("res://scenes/tool_bar/button_hover.tres")

## Scroll area sized so ~3 tile rows + label fit without clipping the bottom row.
const POPUP_WIDTH := 328
const POPUP_HEIGHT := 380

@export var graph_controller_path: NodePath = ^"../GraphController"

@onready var _presets_btn: Button = $Margin/TriggerPanel/HBox/PresetsButton
@onready var _share_btn: Button = $Margin/TriggerPanel/HBox/ShareButton
@onready var _popup: Popup = $PresetsPopup

var _graph_controller: GraphController


func _ready() -> void:
	_graph_controller = get_node_or_null(graph_controller_path) as GraphController
	if _graph_controller == null:
		push_warning("PresetPicker: GraphController not found at %s" % str(graph_controller_path))
	_style_top_right_panel()
	_presets_btn.pressed.connect(_on_trigger_pressed)
	_share_btn.pressed.connect(_on_share_btn_pressed)
	_popup.visibility_changed.connect(_on_popup_visibility_changed)
	_build_grid()


func _style_top_right_panel() -> void:
	var pad := 7.0
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

	for btn: Button in [_share_btn, _presets_btn]:
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		btn.custom_minimum_size = Vector2(84, 44)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = false
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = false
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("h_separation", 6)
		btn.add_theme_constant_override("icon_max_width", 18)
		btn.add_theme_stylebox_override("normal", normal_sb)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_stylebox_override("pressed", hover_sb)
		btn.add_theme_stylebox_override("focus", hover_sb)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.118, 0.118, 0.18))
		btn.add_theme_color_override("font_hover_color", Color(0.263, 0.38, 0.933))
		btn.add_theme_color_override("font_pressed_color", Color(0.263, 0.38, 0.933))
		btn.add_theme_color_override("font_focus_color", Color(0.263, 0.38, 0.933))

	_share_btn.icon = SHARE_TOOLBAR_ICON
	_presets_btn.icon = TRIGGER_TOOLBAR_ICON

	var sep := $Margin/TriggerPanel/HBox/Separator as VSeparator
	if sep:
		sep.add_theme_color_override("color", Color(0.86, 0.86, 0.88))

	var tp: PanelContainer = $Margin/TriggerPanel
	if tp:
		tp.size_flags_horizontal = Control.SIZE_SHRINK_END
		tp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _build_grid() -> void:
	var grid: GridContainer = $PresetsPopup/PanelRoot/Margin/Scroll/Grid
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
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(0, 58)
		tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(cap)
		vb.add_child(tex_rect)

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
	var gp := _presets_btn.get_global_rect()
	_popup.size = Vector2i(POPUP_WIDTH, POPUP_HEIGHT)
	var x := int(gp.position.x + gp.size.x - _popup.size.x)
	var y := int(gp.position.y + gp.size.y + 8)
	var vp := get_viewport().get_visible_rect().size
	x = clampi(x, 8, int(vp.x) - _popup.size.x - 8)
	y = clampi(y, 8, int(vp.y) - _popup.size.y - 8)
	_popup.position = Vector2i(x, y)
	_popup.popup()


func _on_share_btn_pressed() -> void:
	var share_panel := get_node_or_null("../SharePanel") as SharePanel
	if share_panel:
		share_panel.toggle_popup(_share_btn.get_global_rect())


func _on_popup_visibility_changed() -> void:
	if _popup.visible:
		get_tree().call_group("preset_live_thumbnails", "refresh")
