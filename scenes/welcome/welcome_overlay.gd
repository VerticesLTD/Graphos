## First-visit welcome: Graphos preset on canvas; Create/Connect rows dim on first new vertex/edge; full overlay fades when an algorithm starts.
extends CanvasLayer

const _WelcomeLayoutScript := preload("res://scenes/welcome/welcome_layout.gd")

const _GRAPHOS_PRESET := "res://core/presets/data/graphos.json"
const _TEXT_FADE_SEC := 1.35
const _ROW_DIM_SEC := 0.45
## Opacity for a completed instruction row (Create / Connect).
const _COMPLETED_ROW_ALPHA := 0.2

## Preset centroid (viewport height fraction).
const _GRAPH_SCREEN_Y_FRAC := 0.28
const _TEXT_COLUMN_TOP_FRAC := 0.36

const _TITLE_GRAY := Color(0.118, 0.118, 0.18, 1)
const _BODY_GRAY := Color(0.28, 0.28, 0.34, 1)

const _FONT_UI: FontFile = preload("res://assets/fonts/latinmodern-math.otf")

@onready var _fade_target: Control = $Root/Column/WelcomeContent
@onready var _instruction_block: VBoxContainer = $Root/Column/WelcomeContent/InstructionShift/CenterRows/InstructionBlock
@onready var _row_create: HBoxContainer = $Root/Column/WelcomeContent/InstructionShift/CenterRows/InstructionBlock/RowCreate
@onready var _row_connect: HBoxContainer = $Root/Column/WelcomeContent/InstructionShift/CenterRows/InstructionBlock/RowConnect
@onready var _title: Label = $Root/Column/WelcomeContent/Title
@onready var _column: VBoxContainer = $Root/Column

var _algorithm_player: AlgorithmPlayer
var _finishing := false
var _text_tween: Tween
var _baseline_vertices: int = 0
var _baseline_edges: int = 0
var _create_row_dimmed := false
var _connect_row_dimmed := false


func _ready() -> void:
	if FirstVisitStore.has_seen_welcome():
		queue_free()
		return

	layer = 12

	call_deferred("_layout_and_bootstrap")
	call_deferred("_apply_grid_nudge")
	call_deferred("_connect_dismiss_signals")

	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_propagate_mouse_ignore($Root)


func _layout_and_bootstrap() -> void:
	_position_welcome_column()
	_apply_typography()
	_tint_row_icons()
	_bootstrap_welcome_graph()


func _position_welcome_column() -> void:
	var sz := get_viewport().get_visible_rect().size
	_column.offset_top = sz.y * _TEXT_COLUMN_TOP_FRAC
	_column.offset_bottom = minf(sz.y * 0.9, _column.offset_top + 420.0)


func _apply_typography() -> void:
	_title.add_theme_font_override("font", _FONT_UI)
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", _TITLE_GRAY)
	_title.add_theme_constant_override("line_spacing", 2)

	for row in _instruction_block.get_children():
		if not row is HBoxContainer:
			continue
		for cell in row.get_children():
			if cell is Label:
				var lab: Label = cell
				lab.add_theme_font_override("font", _FONT_UI)
				lab.add_theme_font_size_override("font_size", 14)
				lab.add_theme_color_override("font_color", _BODY_GRAY)
				lab.add_theme_constant_override("line_spacing", 4)
				lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _tint_row_icons() -> void:
	for row in _instruction_block.get_children():
		if not row is HBoxContainer:
			continue
		for cell in row.get_children():
			if cell is TextureRect:
				(cell as TextureRect).self_modulate = Globals.BUTTON_HIGHLIGHT_MODULATE


func _apply_grid_nudge() -> void:
	var cam := get_node_or_null("../Camera") as Camera2D
	_WelcomeLayoutScript.nudge_welcome_stack_off_grid_lines(_column, cam)


func _bootstrap_welcome_graph() -> void:
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null:
		return
	var sz := get_viewport().get_visible_rect().size
	var screen_pt := Vector2(sz.x * 0.5, sz.y * _GRAPH_SCREEN_Y_FRAC)
	if gc.graph.vertices.is_empty():
		gc.insert_preset_from_json_path_at_screen_point(_GRAPHOS_PRESET, screen_pt)
	_baseline_vertices = gc.graph.vertices.size()
	_baseline_edges = gc.graph.num_edges
	call_deferred("_after_welcome_graph_sync")


func _after_welcome_graph_sync() -> void:
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc:
		gc.clear_selection_buffer()
	Globals.current_state = Globals.State.CREATE


func _propagate_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_propagate_mouse_ignore(c)


func _connect_dismiss_signals() -> void:
	_algorithm_player = get_node_or_null("../GraphController/AlgorithmPlayer") as AlgorithmPlayer
	if _algorithm_player:
		if not _algorithm_player.algorithm_run_started.is_connected(_on_algorithm_started_dismiss):
			_algorithm_player.algorithm_run_started.connect(_on_algorithm_started_dismiss)
	if not CommandManager.state_changed.is_connected(_on_command_state_for_welcome):
		CommandManager.state_changed.connect(_on_command_state_for_welcome)


func _on_command_state_for_welcome() -> void:
	if _finishing:
		return
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null:
		return
	var g: Graph = gc.graph
	if not _create_row_dimmed and g.vertices.size() >= _baseline_vertices + 1:
		_create_row_dimmed = true
		_dim_instruction_row(_row_create)
	if not _connect_row_dimmed and g.num_edges >= _baseline_edges + 1:
		_connect_row_dimmed = true
		_dim_instruction_row(_row_connect)


func _dim_instruction_row(row: Control) -> void:
	if row == null:
		return
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "modulate:a", _COMPLETED_ROW_ALPHA, _ROW_DIM_SEC)


func _on_algorithm_started_dismiss() -> void:
	if _finishing:
		return
	_finishing = true
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_algorithm_started_dismiss):
		_algorithm_player.algorithm_run_started.disconnect(_on_algorithm_started_dismiss)
	if CommandManager.state_changed.is_connected(_on_command_state_for_welcome):
		CommandManager.state_changed.disconnect(_on_command_state_for_welcome)
	_run_dismiss_sequence()


func _run_dismiss_sequence() -> void:
	if _text_tween:
		_text_tween.kill()
		_text_tween = null

	_text_tween = create_tween()
	_text_tween.set_ease(Tween.EASE_IN_OUT)
	_text_tween.set_trans(Tween.TRANS_SINE)
	_text_tween.tween_property(_fade_target, "modulate:a", 0.0, _TEXT_FADE_SEC)
	_text_tween.tween_callback(_finish_and_free)


func _finish_and_free() -> void:
	FirstVisitStore.mark_welcome_seen()
	queue_free()


func _exit_tree() -> void:
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_algorithm_started_dismiss):
		_algorithm_player.algorithm_run_started.disconnect(_on_algorithm_started_dismiss)
	if CommandManager.state_changed.is_connected(_on_command_state_for_welcome):
		CommandManager.state_changed.disconnect(_on_command_state_for_welcome)
