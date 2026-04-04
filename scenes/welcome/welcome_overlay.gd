## First-visit welcome: graph snapped to a design board ratio; title + rows live in
## world space so they pan/scroll with the grid instead of staying fixed on screen.
extends CanvasLayer

const _GRAPHOS_PRESET := "res://core/presets/data/graphos.json"
const _TEXT_FADE_SEC := 1.35
const _ROW_DIM_SEC := 0.45
const _COMPLETED_ROW_ALPHA := 0.2

## Reference artboard (any resolution — only ratios matter). Matches a 1920×1080 comp.
const _REF_BOARD := Vector2(1920.0, 1080.0)
## Graph sits roughly in the upper-center; text follows below it.
const _LOGO_CENTER_BOARD := Vector2(960.0, 310.0)
const _TITLE_CENTER_BOARD := Vector2(960.0, 505.0)
const _INSTRUCTIONS_TOP_CENTER_BOARD := Vector2(960.0, 575.0)
## Extra shift right for the instruction block vs title (board pixels; scales with viewport width).
const _INSTRUCTIONS_NUDGE_X_BOARD := 44.0

const _MATH_GRID_MINOR := 44.0
const _WELCOME_GRAPH_RADIUS_INSET := _MATH_GRID_MINOR * 1.25
const _WELCOME_GRAPH_MIN_SHRINK_FACTOR := 0.86
const _INSTRUCTIONS_MAX_WIDTH_FRAC := 0.92

const _TITLE_FONT_SIZE := 42
const _ROW_FONT_SIZE := 13

const _TITLE_GRAY := Color(0.118, 0.118, 0.18, 1)
const _BODY_GRAY := Color(0.28, 0.28, 0.34, 1)

@onready var _title: Label = $Root/Title
@onready var _instruction_shift: MarginContainer = $Root/InstructionShift
@onready var _instruction_block: VBoxContainer = $Root/InstructionShift/CenterRows/InstructionBlock
@onready var _row_create: HBoxContainer = $Root/InstructionShift/CenterRows/InstructionBlock/RowCreate
@onready var _row_connect: HBoxContainer = $Root/InstructionShift/CenterRows/InstructionBlock/RowConnect

var _algorithm_player: AlgorithmPlayer
var _finishing := false
var _text_tween: Tween
var _create_row_dimmed := false
var _connect_row_dimmed := false
var _pasted_welcome_preset := false
## World-space container that holds the title and instruction labels so they
## travel with the canvas when the user pans or zooms.
var _world_text_root: Node2D = null


func _ready() -> void:
	if FirstVisitStore.has_seen_welcome():
		queue_free()
		return

	call_deferred("_bootstrap_welcome_flow")
	call_deferred("_connect_dismiss_signals")
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_propagate_mouse_ignore($Root)


func _on_viewport_size_changed() -> void:
	if _finishing or not is_inside_tree() or not _pasted_welcome_preset:
		return
	_snap_graph_centroid_to_board_logo()
	_layout_welcome_ui.call_deferred()


# ---------- coordinate helpers ----------

func _board_to_viewport_point(board_px: Vector2) -> Vector2:
	var r := get_viewport().get_visible_rect()
	return r.position + Vector2(
		r.size.x * (board_px.x / _REF_BOARD.x),
		r.size.y * (board_px.y / _REF_BOARD.y)
	)


## Convert a screen-space point to world (canvas) coordinates.
func _screen_to_world(screen_pt: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pt


## Map a board-ratio position directly to world coordinates.
func _board_to_world_point(board_px: Vector2) -> Vector2:
	return _screen_to_world(_board_to_viewport_point(board_px))


# ---------- bootstrap ----------

func _bootstrap_welcome_flow() -> void:
	_apply_typography()
	_tint_row_icons()
	_bootstrap_welcome_graph()
	call_deferred("_after_welcome_graph_sync")


func _apply_typography() -> void:
	var title_font: Font = load("res://assets/fonts/latinmodern-math.otf")
	_title.add_theme_font_override("font", title_font)
	_title.add_theme_font_size_override("font_size", _TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", _TITLE_GRAY)
	_title.add_theme_constant_override("line_spacing", 4)

	for row in _instruction_block.get_children():
		if not row is HBoxContainer:
			continue
		for cell in row.get_children():
			if cell is Label:
				var lab: Label = cell
				lab.remove_theme_font_override("font")
				lab.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
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


func _bootstrap_welcome_graph() -> void:
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null:
		return
	var screen_pt := _board_to_viewport_point(_LOGO_CENTER_BOARD)
	if gc.graph.vertices.is_empty():
		gc.insert_preset_from_json_path_at_screen_point(_GRAPHOS_PRESET, screen_pt)
		_pasted_welcome_preset = true
		call_deferred("_after_welcome_graph_sync")


func _after_welcome_graph_sync() -> void:
	if _pasted_welcome_preset:
		_shrink_welcome_graph_toward_centroid()
		_snap_graph_centroid_to_board_logo()
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc:
		gc.clear_selection_buffer()
	Globals.current_state = Globals.State.CREATE
	# Guard: only create the world-space text container once even if called twice.
	if _world_text_root == null:
		_create_world_text_container()
	await get_tree().process_frame
	_layout_welcome_ui()


## Move the title and instruction nodes out of the CanvasLayer (screen space) and
## into a plain Node2D sibling (world space) so they travel with the grid on pan/zoom.
func _create_world_text_container() -> void:
	_world_text_root = Node2D.new()
	_world_text_root.name = "WelcomeTextWorld"
	get_parent().add_child(_world_text_root)
	_title.reparent(_world_text_root, false)
	_instruction_shift.reparent(_world_text_root, false)
	_propagate_mouse_ignore(_world_text_root)


func _snap_graph_centroid_to_board_logo() -> void:
	if not _pasted_welcome_preset:
		return
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null or gc.graph.vertices.is_empty():
		return
	var target_screen := _board_to_viewport_point(_LOGO_CENTER_BOARD)
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var target_canvas: Vector2 = inv * target_screen
	var g: Graph = gc.graph
	var acc := Vector2.ZERO
	for v: Vertex in g.vertices.values():
		acc += g.to_global(v.pos)
	acc /= float(g.vertices.size())
	var delta: Vector2 = target_canvas - acc
	for v: Vertex in g.vertices.values():
		v.pos += delta


func _shrink_welcome_graph_toward_centroid() -> void:
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null:
		return
	var verts: Array = gc.graph.vertices.values()
	if verts.is_empty():
		return
	var center := Vector2.ZERO
	for v: Vertex in verts:
		center += v.pos
	center /= float(verts.size())
	var max_r := 0.0
	for v: Vertex in verts:
		max_r = maxf(max_r, center.distance_to(v.pos))
	if max_r < 2.0:
		return
	var target_r := maxf(max_r - _WELCOME_GRAPH_RADIUS_INSET, max_r * _WELCOME_GRAPH_MIN_SHRINK_FACTOR)
	var factor := target_r / max_r
	for v: Vertex in verts:
		v.pos = center + (v.pos - center) * factor


# ---------- layout ----------

func _layout_welcome_ui() -> void:
	if not is_instance_valid(_title) or not is_instance_valid(_instruction_shift):
		return
	if not is_instance_valid(_world_text_root):
		return

	var r := get_viewport().get_visible_rect()

	# All positions are converted to world coordinates so the text lives on the grid.
	var title_world := _board_to_world_point(_TITLE_CENTER_BOARD)

	# Build the instruction anchor in screen space first (so the nudge is in screen pixels),
	# then convert to world.
	var instr_screen := _board_to_viewport_point(_INSTRUCTIONS_TOP_CENTER_BOARD)
	instr_screen.x += r.size.x * (_INSTRUCTIONS_NUDGE_X_BOARD / _REF_BOARD.x)
	var instr_world := _screen_to_world(instr_screen)

	_title.reset_size()
	_instruction_block.custom_minimum_size.x = minf(492.0, r.size.x * _INSTRUCTIONS_MAX_WIDTH_FRAC - 80.0)
	_instruction_shift.reset_size()

	await get_tree().process_frame

	var ts: Vector2 = _title.get_combined_minimum_size()
	if ts.x < 1.0 or ts.y < 1.0:
		ts = _title.size
	_title.custom_minimum_size = ts
	_title.size = ts
	_title.position = title_world - ts * 0.5

	await get_tree().process_frame

	var ib_size: Vector2 = _instruction_shift.size
	if ib_size.x < 1.0:
		ib_size = _instruction_shift.get_combined_minimum_size()
	_instruction_shift.position = Vector2(instr_world.x - ib_size.x * 0.5, instr_world.y)


# ---------- mouse ----------

func _propagate_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_propagate_mouse_ignore(c)


# ---------- dismiss signals ----------

func _connect_dismiss_signals() -> void:
	_algorithm_player = get_node_or_null("../GraphController/AlgorithmPlayer") as AlgorithmPlayer
	if _algorithm_player:
		if not _algorithm_player.algorithm_run_started.is_connected(_on_algorithm_started_dismiss):
			_algorithm_player.algorithm_run_started.connect(_on_algorithm_started_dismiss)
	if not CommandManager.state_changed.is_connected(_on_command_state_for_welcome):
		CommandManager.state_changed.connect(_on_command_state_for_welcome)


func _on_command_state_for_welcome() -> void:
	if _finishing or CommandManager.undo_stack.is_empty():
		return
	var cmd: Command = CommandManager.undo_stack.back()
	if not _create_row_dimmed:
		if cmd is AddVertexCommand:
			var av: AddVertexCommand = cmd as AddVertexCommand
			if not av.from_clipboard_paste:
				_create_row_dimmed = true
				_dim_instruction_row(_row_create)
		elif cmd is PathStepCommand:
			_create_row_dimmed = true
			_dim_instruction_row(_row_create)
	if not _connect_row_dimmed:
		if cmd is AddEdgeCommand:
			var ae: AddEdgeCommand = cmd as AddEdgeCommand
			if not ae.from_clipboard_paste:
				_connect_row_dimmed = true
				_dim_instruction_row(_row_connect)
		elif cmd is PathStepCommand:
			var ps: PathStepCommand = cmd as PathStepCommand
			if ps.e_cmd != null:
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
	get_viewport().size_changed.disconnect(_on_viewport_size_changed)
	_run_dismiss_sequence()


func _run_dismiss_sequence() -> void:
	if _text_tween:
		_text_tween.kill()
		_text_tween = null

	_text_tween = create_tween()
	_text_tween.set_ease(Tween.EASE_IN_OUT)
	_text_tween.set_trans(Tween.TRANS_SINE)
	# Fade the world-space text container; graph vertices are animated separately by the engine.
	if is_instance_valid(_world_text_root):
		_text_tween.tween_property(_world_text_root, "modulate:a", 0.0, _TEXT_FADE_SEC)
	_text_tween.tween_callback(_finish_and_free)


func _finish_and_free() -> void:
	FirstVisitStore.mark_welcome_seen()
	queue_free()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.disconnect(_on_viewport_size_changed)
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_algorithm_started_dismiss):
		_algorithm_player.algorithm_run_started.disconnect(_on_algorithm_started_dismiss)
	if CommandManager.state_changed.is_connected(_on_command_state_for_welcome):
		CommandManager.state_changed.disconnect(_on_command_state_for_welcome)
	# Free the world-space text container which is a sibling, not a child of this node.
	if is_instance_valid(_world_text_root):
		_world_text_root.queue_free()
