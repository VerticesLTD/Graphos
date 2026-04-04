## First-visit welcome: Graphos logo (preset viewport) above copy; real preset still pastes on empty graph; grid-aware vertical nudge.
extends CanvasLayer

const _WelcomeLayoutScript := preload("res://scenes/welcome/welcome_layout.gd")

const _GRAPHOS_PRESET := "res://core/presets/data/graphos.json"
const _AUTO_DISMISS_SEC := 60.0
const _TEXT_FADE_SEC := 1.35

const _TITLE_GRAY := Color(0.118, 0.118, 0.18, 1)
const _BODY_GRAY := Color(0.592, 0.592, 0.624, 1)

@onready var _fade_target: Control = $Root/Column/WelcomeContent
@onready var _welcome_content: VBoxContainer = $Root/Column/WelcomeContent
@onready var _logo_thumb: PresetLiveThumbnail = $Root/Column/WelcomeContent/LogoHolder/WelcomeGraphLogo
@onready var _title: Label = $Root/Column/WelcomeContent/Title
@onready var _column: VBoxContainer = $Root/Column
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

	_setup_logo_viewport()
	_apply_typography()
	_tint_row_icons()
	call_deferred("_bootstrap_welcome_graph")
	call_deferred("_apply_grid_nudge")
	call_deferred("_connect_algorithm_player")

	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_propagate_mouse_ignore($Root)


func _setup_logo_viewport() -> void:
	_logo_thumb.configure(_GRAPHOS_PRESET)


func _apply_typography() -> void:
	_title.add_theme_color_override("font_color", _TITLE_GRAY)
	_title.add_theme_font_size_override("font_size", 19)

	for child in _welcome_content.get_children():
		if child is HBoxContainer:
			for cell in child.get_children():
				if cell is Label:
					var lab: Label = cell
					lab.add_theme_color_override("font_color", _BODY_GRAY)
					lab.add_theme_font_size_override("font_size", 13)


func _tint_row_icons() -> void:
	for child in _welcome_content.get_children():
		if not child is HBoxContainer:
			continue
		for cell in child.get_children():
			if cell is TextureRect:
				(cell as TextureRect).self_modulate = Globals.BUTTON_HIGHLIGHT_MODULATE


func _apply_grid_nudge() -> void:
	var cam := get_node_or_null("../Camera") as Camera2D
	_WelcomeLayoutScript.nudge_welcome_stack_off_grid_lines(_column, cam)


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
