## First-visit welcome: Graphos preset on the real graph; floating copy on the grid (no panel), Excalidraw-style spacing.
extends CanvasLayer

const _GRAPHOS_PRESET := "res://core/presets/data/graphos.json"
const _AUTO_DISMISS_SEC := 60.0
const _TEXT_FADE_SEC := 1.35

## Aligns with toolbar / preset picker copy (Graphos chrome).
const _TITLE_GRAY := Color(0.118, 0.118, 0.18, 1)
const _BODY_GRAY := Color(0.592, 0.592, 0.624, 1)

@onready var _fade_target: Control = $Root/Column/TextBlock
@onready var _text_block: VBoxContainer = $Root/Column/TextBlock
@onready var _title: Label = $Root/Column/TextBlock/Title
@onready var _blurb: Label = $Root/Column/TextBlock/Blurb
@onready var _closing: Label = $Root/Column/TextBlock/Closing
@onready var _timer: Timer = $AutoDismissTimer

var _algorithm_player: AlgorithmPlayer
var _finishing := false
var _text_tween: Tween


func _ready() -> void:
	if FirstVisitStore.has_seen_welcome():
		queue_free()
		return

	layer = 12
	_timer.wait_time = _AUTO_DISMISS_SEC
	_timer.one_shot = true
	_timer.timeout.connect(_on_dismiss_requested)
	_timer.start()

	_apply_typography()
	_tint_row_icons()
	call_deferred("_bootstrap_welcome_graph")
	call_deferred("_connect_algorithm_player")

	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_propagate_mouse_ignore($Root)


func _apply_typography() -> void:
	_title.add_theme_color_override("font_color", _TITLE_GRAY)
	_title.add_theme_font_size_override("font_size", 19)

	_blurb.add_theme_color_override("font_color", _BODY_GRAY)
	_blurb.add_theme_font_size_override("font_size", 12)

	_closing.add_theme_color_override("font_color", _BODY_GRAY)
	_closing.add_theme_font_size_override("font_size", 12)

	for row in _text_block.get_children():
		if not row is HBoxContainer:
			continue
		for cell in row.get_children():
			if cell is Label:
				var lab: Label = cell
				lab.add_theme_color_override("font_color", _BODY_GRAY)
				lab.add_theme_font_size_override("font_size", 13)


func _tint_row_icons() -> void:
	for row in _text_block.get_children():
		if not row is HBoxContainer:
			continue
		for cell in row.get_children():
			if cell is TextureRect:
				(cell as TextureRect).self_modulate = Globals.BUTTON_HIGHLIGHT_MODULATE


func _bootstrap_welcome_graph() -> void:
	var gc := get_node_or_null("../GraphController") as GraphController
	if gc == null or gc.graph == null:
		return
	if gc.graph.vertices.is_empty():
		gc.insert_preset_from_json_path(_GRAPHOS_PRESET)


func _propagate_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_propagate_mouse_ignore(c)


func _connect_algorithm_player() -> void:
	_algorithm_player = get_node_or_null("../GraphController/AlgorithmPlayer") as AlgorithmPlayer
	if _algorithm_player:
		if not _algorithm_player.algorithm_run_started.is_connected(_on_dismiss_requested):
			_algorithm_player.algorithm_run_started.connect(_on_dismiss_requested)


func _on_dismiss_requested() -> void:
	if _finishing:
		return
	_finishing = true
	_timer.stop()
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_dismiss_requested):
		_algorithm_player.algorithm_run_started.disconnect(_on_dismiss_requested)
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
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_dismiss_requested):
		_algorithm_player.algorithm_run_started.disconnect(_on_dismiss_requested)
