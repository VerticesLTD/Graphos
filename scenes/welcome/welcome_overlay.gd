## First-visit welcome: Graphos logo (preset vertices) + copy; text fades on algorithm start or timeout, then overlay exits.
extends CanvasLayer

const _GRAPHOS_PRESET := "res://core/presets/data/graphos.json"
const _AUTO_DISMISS_SEC := 60.0
const _TEXT_FADE_SEC := 1.35
const _LOGO_FADE_SEC := 0.55

@onready var _logo_holder: Control = $Root/Column/LogoHolder
@onready var _logo_thumb: PresetLiveThumbnail = $Root/Column/LogoHolder/PresetLiveThumbnail
@onready var _text_root: Control = $Root/Column/TextBlock
@onready var _timer: Timer = $AutoDismissTimer

var _algorithm_player: AlgorithmPlayer
var _finishing := false
var _text_tween: Tween
var _logo_tween: Tween


func _ready() -> void:
	if FirstVisitStore.has_seen_welcome():
		queue_free()
		return

	layer = 12
	_timer.wait_time = _AUTO_DISMISS_SEC
	_timer.one_shot = true
	_timer.timeout.connect(_on_dismiss_requested)
	_timer.start()

	_setup_logo()
	call_deferred("_connect_algorithm_player")

	mouse_filter = MOUSE_FILTER_IGNORE
	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _connect_algorithm_player() -> void:
	_algorithm_player = get_node_or_null("../GraphController/AlgorithmPlayer") as AlgorithmPlayer
	if _algorithm_player:
		if not _algorithm_player.algorithm_run_started.is_connected(_on_dismiss_requested):
			_algorithm_player.algorithm_run_started.connect(_on_dismiss_requested)


func _setup_logo() -> void:
	_logo_thumb.set_mini_background(Color(0, 0, 0, 0))
	_logo_thumb.configure(_GRAPHOS_PRESET)
	_logo_holder.custom_minimum_size = Vector2(280, 168)
	_logo_thumb.custom_minimum_size = Vector2(280, 168)
	var vp: SubViewport = _logo_thumb.get_node_or_null("SubViewportContainer/SubViewport") as SubViewport
	if vp:
		vp.size = Vector2i(280, 168)


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
	if _logo_tween:
		_logo_tween.kill()
		_logo_tween = null

	_text_tween = create_tween()
	_text_tween.set_parallel(false)
	_text_tween.set_ease(Tween.EASE_IN_OUT)
	_text_tween.set_trans(Tween.TRANS_SINE)
	_text_tween.tween_property(_text_root, "modulate:a", 0.0, _TEXT_FADE_SEC)
	_text_tween.chain().callback(_fade_logo_and_finish)


func _fade_logo_and_finish() -> void:
	if _logo_tween:
		_logo_tween.kill()
	_logo_tween = create_tween()
	_logo_tween.set_ease(Tween.EASE_IN_OUT)
	_logo_tween.set_trans(Tween.TRANS_SINE)
	_logo_tween.tween_property(_logo_holder, "modulate:a", 0.0, _LOGO_FADE_SEC)
	_logo_tween.chain().callback(_finish_and_free)


func _finish_and_free() -> void:
	FirstVisitStore.mark_welcome_seen()
	queue_free()


func _exit_tree() -> void:
	if _algorithm_player and _algorithm_player.algorithm_run_started.is_connected(_on_dismiss_requested):
		_algorithm_player.algorithm_run_started.disconnect(_on_dismiss_requested)
