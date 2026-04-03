## Floating Share button (top-right, just left of Presets) + popup dialog.
##
## Web-only: the button is hidden on desktop builds.
## Popup is built entirely in code for full styling control.
## Node refs are resolved at _ready() time via relative paths — no @export wiring needed.
extends CanvasLayer
class_name SharePanel

const SHARE_ICON: Texture2D = preload("res://assets/icons/share_icon.svg")
const STYLE_BTN_NORMAL: StyleBox = preload("res://scenes/tool_bar/button_normal.tres")
const STYLE_BTN_HOVER: StyleBox = preload("res://scenes/tool_bar/button_hover.tres")
const TOOLBAR_BG: StyleBox = preload("res://scenes/tool_bar/tool_bar_background.tres")

const ACCENT := Color(0.263, 0.38, 0.933)
const ACCENT_HOVER := Color(0.2, 0.3, 0.85)
const SUCCESS := Color(0.18, 0.66, 0.44)
const SUCCESS_HOVER := Color(0.15, 0.58, 0.38)
const DARK := Color(0.118, 0.118, 0.18)
const MUTED := Color(0.44, 0.44, 0.55)

const POPUP_WIDTH := 360
const POPUP_HEIGHT := 192
const COPY_RESET_SECS := 2.0

@onready var _trigger: Button = $Margin/TriggerPanel/ShareButton
@onready var _popup: Popup = $SharePopup
@onready var _share_manager: ShareManager = get_node_or_null("../ShareManager") as ShareManager
@onready var _graph: Graph = get_node_or_null("../UndirectedGraph") as Graph
@onready var _camera: Camera2D = get_node_or_null("../Camera") as Camera2D
@onready var _grid: MathGridBackground = get_node_or_null("../MathGridBackground") as MathGridBackground

var _url_field: LineEdit
var _copy_btn: Button
var _copy_timer: Timer
var _current_url: String = ""


func _ready() -> void:
	if not OS.has_feature("web"):
		$Margin.visible = false
		return
	_style_trigger()
	_build_popup()
	_trigger.pressed.connect(_on_trigger_pressed)


# ---------------------------------------------------------------------------
# Trigger button
# ---------------------------------------------------------------------------

func _style_trigger() -> void:
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
	_trigger.icon = SHARE_ICON
	_trigger.text = "Share"
	_trigger.custom_minimum_size = Vector2(100, 52)
	_trigger.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_trigger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_trigger.add_theme_color_override("font_color", DARK)
	_trigger.add_theme_color_override("font_hover_color", ACCENT)
	_trigger.add_theme_color_override("font_pressed_color", ACCENT)
	_trigger.add_theme_color_override("font_focus_color", ACCENT)

	var tp: PanelContainer = _trigger.get_parent() as PanelContainer
	if tp:
		tp.size_flags_horizontal = Control.SIZE_SHRINK_END
		tp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


# ---------------------------------------------------------------------------
# Popup construction
# ---------------------------------------------------------------------------

func _build_popup() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: StyleBoxFlat = TOOLBAR_BG.duplicate() as StyleBoxFlat
	bg.expand_margin_left = 0
	bg.expand_margin_top = 0
	bg.expand_margin_right = 0
	bg.expand_margin_bottom = 0
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", bg)
	_popup.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# — Header ----------------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	vbox.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.texture = SHARE_ICON
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_rect.custom_minimum_size = Vector2(18, 18)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon_rect)

	var title := Label.new()
	title.text = "Share this graph"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# — Separator -------------------------------------------------------------
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.878, 0.878, 0.878))
	vbox.add_child(sep)

	# — Sub-label -------------------------------------------------------------
	var sub := Label.new()
	sub.text = "Copy the link below to share your graph:"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", MUTED)
	vbox.add_child(sub)

	# — URL row ---------------------------------------------------------------
	var url_row := HBoxContainer.new()
	url_row.add_theme_constant_override("separation", 6)
	vbox.add_child(url_row)

	_url_field = LineEdit.new()
	_url_field.editable = false
	_url_field.placeholder_text = "Generating link…"
	_url_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_url_field.add_theme_font_size_override("font_size", 11)
	_url_field.add_theme_color_override("font_color", DARK)
	_url_field.add_theme_color_override("font_placeholder_color", MUTED)
	var field_bg := StyleBoxFlat.new()
	field_bg.bg_color = Color(0.94, 0.94, 0.96)
	field_bg.set_corner_radius_all(6)
	field_bg.content_margin_left = 8
	field_bg.content_margin_right = 8
	field_bg.content_margin_top = 6
	field_bg.content_margin_bottom = 6
	_url_field.add_theme_stylebox_override("normal", field_bg)
	_url_field.add_theme_stylebox_override("read_only", field_bg)
	_url_field.add_theme_stylebox_override("focus", field_bg)
	_url_field.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	url_row.add_child(_url_field)

	_copy_btn = _make_accent_button("Copy link", ACCENT, ACCENT_HOVER)
	_copy_btn.pressed.connect(_on_copy_pressed)
	url_row.add_child(_copy_btn)

	# — Info text -------------------------------------------------------------
	var info := Label.new()
	info.text = "Anyone with the link can view and edit this graph."
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	# — Copy-reset timer ------------------------------------------------------
	_copy_timer = Timer.new()
	_copy_timer.wait_time = COPY_RESET_SECS
	_copy_timer.one_shot = true
	_copy_timer.timeout.connect(_on_copy_timer_timeout)
	_popup.add_child(_copy_timer)

	_url_field.gui_input.connect(_on_url_field_input)


func _make_accent_button(label: String, color: Color, hover_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(90, 0)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = color
	normal_sb.set_corner_radius_all(6)
	normal_sb.content_margin_left = 12
	normal_sb.content_margin_right = 12
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6

	var hover_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = hover_color

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_stylebox_override("focus", normal_sb)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	return btn


# ---------------------------------------------------------------------------
# Popup display
# ---------------------------------------------------------------------------

func _on_trigger_pressed() -> void:
	if _popup.visible:
		_popup.hide()
		return

	_current_url = ""
	_url_field.text = ""
	_url_field.placeholder_text = "Generating link…"
	_reset_copy_button()

	if _share_manager and _graph and _camera and _grid:
		_current_url = _share_manager.get_share_url(_graph, _camera, _grid.grid_enabled)
		_url_field.text = _current_url

	_popup.size = Vector2i(POPUP_WIDTH, POPUP_HEIGHT)

	var gp := _trigger.get_global_rect()
	var x := int(gp.position.x + gp.size.x - POPUP_WIDTH)
	var y := int(gp.position.y + gp.size.y + 8)
	var vp := get_viewport().get_visible_rect().size
	x = clampi(x, 8, int(vp.x) - POPUP_WIDTH - 8)
	y = clampi(y, 8, int(vp.y) - POPUP_HEIGHT - 8)
	_popup.position = Vector2i(x, y)
	_popup.popup()


# ---------------------------------------------------------------------------
# Copy behaviour
# ---------------------------------------------------------------------------

func _on_url_field_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_url_field.select_all()


func _on_copy_pressed() -> void:
	if _current_url.is_empty():
		return
	if _share_manager:
		_share_manager.copy_to_clipboard(_current_url)
	Notify.show_notification("Link copied to clipboard!")
	_set_copy_success()
	_copy_timer.start()


func _set_copy_success() -> void:
	_copy_btn.text = "Copied!"
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = SUCCESS
	normal_sb.set_corner_radius_all(6)
	normal_sb.content_margin_left = 12
	normal_sb.content_margin_right = 12
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6
	var hover_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = SUCCESS_HOVER
	_copy_btn.add_theme_stylebox_override("normal", normal_sb)
	_copy_btn.add_theme_stylebox_override("hover", hover_sb)
	_copy_btn.add_theme_stylebox_override("pressed", hover_sb)


func _reset_copy_button() -> void:
	if _copy_btn == null:
		return
	_copy_btn.text = "Copy link"
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = ACCENT
	normal_sb.set_corner_radius_all(6)
	normal_sb.content_margin_left = 12
	normal_sb.content_margin_right = 12
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6
	var hover_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = ACCENT_HOVER
	_copy_btn.add_theme_stylebox_override("normal", normal_sb)
	_copy_btn.add_theme_stylebox_override("hover", hover_sb)
	_copy_btn.add_theme_stylebox_override("pressed", hover_sb)


func _on_copy_timer_timeout() -> void:
	_reset_copy_button()
