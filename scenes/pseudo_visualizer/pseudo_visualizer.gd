@tool
extends PanelContainer

@export var data: PseudoCodeData:
	set(value):
		if data and data.changed.is_connected(_on_data_changed):
			data.changed.disconnect(_on_data_changed)

		data = value

		if data:
			data.changed.connect(_on_data_changed)

		_refresh_view()

@export var highlight_color: Color = Color("445566"):
	set(value):
		highlight_color = value
		_refresh_view()

@export var default_font_color: Color = Color("e0e0e0"):
	set(value):
		default_font_color = value
		_refresh_view()

@export var current_step_idx: int = 0:
	set(value):
		# This check is IMPORTANT. Prevents stack overflow.
		if current_step_idx == value:
			return

		current_step_idx = value
		_refresh_view()

@onready var code_display: RichTextLabel = $VBoxContainer/PseudoDisplay
@onready var title: Label = $VBoxContainer/Title

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_refresh_view()

func _has_point(point: Vector2) -> bool:
	# This calculation is done to ensure clicks register in the corners as well (its an override)
	var style = get_theme_stylebox("panel")
	var extra_hitbox_margin = style.expand_margin_left
	var expanded_rect: Rect2 = Rect2(Vector2.ZERO, size).grow(extra_hitbox_margin)
	return expanded_rect.has_point(point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func _refresh_view() -> void:
	if not is_node_ready() or not data or not code_display:
		return

	if data.steps.size() > 0:
		current_step_idx = clampi(current_step_idx,0,data.steps.size() - 1)
	
	title.text = data.algorithm_name
	
	render_step(current_step_idx)

func _on_data_changed() -> void:
	_refresh_view()

func next_step() -> void:
	if not data or current_step_idx >= data.steps.size() -1:
		return
	current_step_idx += 1
	render_step(current_step_idx)
	
func prev_step() -> void:
	if not data or current_step_idx <= 0:
		return
	current_step_idx -= 1
	render_step(current_step_idx)

func render_step(step_idx:int) -> void:
	if data.steps.is_empty() or step_idx >= data.steps.size():
		code_display.text = "[color=red]No steps found or index out of bounds[/color]"
		return

	var lines: PackedStringArray = data.raw_code.split("\n")
	var active_lines: Array = data.steps[step_idx]

	var vibrancy = highlight_color
	vibrancy.s = 1.0
	vibrancy.v = 1.0

	var hex_active: String = "#" + vibrancy.to_html()
	var hex_dim: String = "#" + default_font_color.darkened(0.5).to_html()

	var final_bbcode: String = ""


	for i in range(lines.size()):
		var line: String = lines[i]

		line = line.replace("[","[lb]")
		line = line.replace("\t","    ")

		if i in active_lines:
			line = "[outline_size=2][outline_color=black][color=%s][b]%s. %s[/b][/color][/outline_color][/outline_size]" % [hex_active, i+1, line]
		else:
			line = "[color=%s][b]%s. %s[/b][/color]" % [hex_dim, i+1, line]

		final_bbcode += line + "\n"
	
	code_display.text = final_bbcode
