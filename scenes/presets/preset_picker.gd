## Floating top-right bar: Share (accent-blue CTA) + Presets (white panel) buttons.
extends CanvasLayer

const FALLBACK_TILE_ICON: Texture2D = preload("res://assets/icons/create_tool_icon.svg")
const LIVE_THUMB_SCENE: PackedScene = preload("res://scenes/presets/preset_live_thumbnail.tscn")
const TOOLBAR_BG: StyleBox = preload("res://scenes/tool_bar/tool_bar_background.tres")

const ACCENT       := Color(0.263, 0.38, 0.933)
const ACCENT_HOVER := Color(0.2,   0.3,  0.85)
const DARK         := Color(0.118, 0.118, 0.18)
## Softer blue for the Share outlined button — same family, less vivid.
const SHARE_BLUE   := Color(0.36, 0.48, 0.88)

## Scroll area sized so ~3 tile rows + label fit without clipping the bottom row.
const POPUP_WIDTH := 328
const POPUP_HEIGHT := 380

@export var graph_controller_path: NodePath = ^"../GraphController"

@onready var _presets_btn: Button = $Margin/HBox/PresetsButton
@onready var _share_btn: Button = $Margin/HBox/ShareButton
@onready var _popup: Popup = $PresetsPopup

var _graph_controller: GraphController


func _ready() -> void:
	_graph_controller = get_node_or_null(graph_controller_path) as GraphController
	if _graph_controller == null:
		push_warning("PresetPicker: GraphController not found at %s" % str(graph_controller_path))
	_style_top_right_bar()
	_presets_btn.pressed.connect(_on_trigger_pressed)
	_share_btn.pressed.connect(_on_share_btn_pressed)
	_popup.visibility_changed.connect(_on_popup_visibility_changed)
	_build_grid()


func _style_top_right_bar() -> void:
	# --- Share button: outlined style — primary accent without visual dominance ---
	_share_btn.text = "Share"
	_share_btn.icon = null
	_share_btn.custom_minimum_size = Vector2(76, 36)
	_share_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_share_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_share_btn.focus_mode = Control.FOCUS_NONE
	_share_btn.flat = false
	_share_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	sn.border_width_left   = 2
	sn.border_width_top    = 2
	sn.border_width_right  = 2
	sn.border_width_bottom = 2
	sn.border_color = SHARE_BLUE
	sn.set_corner_radius_all(8)
	sn.shadow_color  = Color(0.36, 0.48, 0.88, 0.15)
	sn.shadow_size   = 4
	sn.shadow_offset = Vector2(0, 1)
	sn.content_margin_left = 14
	sn.content_margin_right = 14
	sn.content_margin_top = 0
	sn.content_margin_bottom = 0
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.94, 0.95, 0.99)
	sh.shadow_size = 0
	_share_btn.add_theme_stylebox_override("normal",  sn)
	_share_btn.add_theme_stylebox_override("hover",   sh)
	_share_btn.add_theme_stylebox_override("pressed", sh)
	_share_btn.add_theme_stylebox_override("focus",   sn)
	_share_btn.add_theme_font_size_override("font_size", 13)
	_share_btn.add_theme_color_override("font_color",         SHARE_BLUE)
	_share_btn.add_theme_color_override("font_hover_color",   SHARE_BLUE)
	_share_btn.add_theme_color_override("font_pressed_color", Color(0.25, 0.36, 0.78))
	_share_btn.add_theme_color_override("font_focus_color",   SHARE_BLUE)

	# --- Presets button: white panel style matching the app chrome ---
	_presets_btn.text = "Presets"
	_presets_btn.icon = null
	_presets_btn.custom_minimum_size = Vector2(84, 36)
	_presets_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_presets_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_presets_btn.focus_mode = Control.FOCUS_NONE
	_presets_btn.flat = false
	_presets_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	pn.border_width_left   = 1
	pn.border_width_top    = 1
	pn.border_width_right  = 1
	pn.border_width_bottom = 1
	pn.border_color = Color(0.878, 0.878, 0.878)
	pn.set_corner_radius_all(8)
	pn.shadow_color  = Color(0, 0, 0, 0.12)
	pn.shadow_size   = 6
	pn.shadow_offset = Vector2(0, 2)
	pn.content_margin_left = 14
	pn.content_margin_right = 14
	pn.content_margin_top = 0
	pn.content_margin_bottom = 0
	var ph := pn.duplicate() as StyleBoxFlat
	ph.bg_color = Color(0.94, 0.94, 0.98)
	ph.shadow_size = 2
	_presets_btn.add_theme_stylebox_override("normal",  pn)
	_presets_btn.add_theme_stylebox_override("hover",   ph)
	_presets_btn.add_theme_stylebox_override("pressed", ph)
	_presets_btn.add_theme_stylebox_override("focus",   pn)
	_presets_btn.add_theme_font_size_override("font_size", 13)
	_presets_btn.add_theme_color_override("font_color",         DARK)
	_presets_btn.add_theme_color_override("font_hover_color",   ACCENT)
	_presets_btn.add_theme_color_override("font_pressed_color", ACCENT)
	_presets_btn.add_theme_color_override("font_focus_color",   DARK)


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
