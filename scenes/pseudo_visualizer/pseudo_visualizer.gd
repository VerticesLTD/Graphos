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
	if Globals.current_state == Globals.State.PAN:
		return

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
	var hex_context: String = "#4f5f8f"
	var hex_dim: String = "#" + default_font_color.to_html()
	var hex_title: String = "#1e1e2e"	
	var primary_line_idx := -1
	if not active_lines.is_empty():
		primary_line_idx = active_lines[active_lines.size() - 1]
	var contextual_lines: Array = []
	if primary_line_idx > 0:
		for j in range(primary_line_idx - 1, -1, -1):
			var trimmed: String = lines[j].strip_edges().to_lower()
			if (
				trimmed.begins_with("while ")
				or trimmed.begins_with("for each ")
				or trimmed.begins_with("if ")
			):
				if not contextual_lines.has(j):
					contextual_lines.append(j)
				if trimmed.begins_with("while "):
					break
	# Keep focus tight: at most 2 context lines + primary.
	contextual_lines.sort()
	if contextual_lines.size() > 2:
		contextual_lines = contextual_lines.slice(contextual_lines.size() - 2, contextual_lines.size())
	var final_bbcode: String = ""
	for i in range(lines.size()):
		var line: String = lines[i]
		line = line.replace("[","[lb]")
		line = line.replace("\t","    ")
		if i == 0:
			line = "[font_size=17][color=%s][b]%s[/b][/color][/font_size]" % [hex_title, line]
		elif i == primary_line_idx:
			# Main focus line: strong text emphasis, no blocky background.
			line = "[font_size=15][color=%s][b]%d.  %s[/b][/color][/font_size]" % [hex_active, i, line]
		elif i in contextual_lines:
			# Gentle context line.
			line = "[font_size=15][color=%s]%d.  %s[/color][/font_size]" % [hex_context, i, line]
		else:
			line = "[font_size=15][color=%s]%d.  %s[/color][/font_size]" % [hex_dim, i, line]
		final_bbcode += line + "\n"
	code_display.text = final_bbcode
