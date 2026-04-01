extends MarginContainer
class_name AlgorithmControls

## User clicked step back
signal step_back
## User clicked step forward
signal step_forward
## Algorithm session stopped entirely
signal stop
## User clicked play (or requested resume)
signal play_requested

const _BASE_INTERVAL := 1.2  # seconds between auto-play steps at ×1.0 speed
const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]

var _playing := false
var _auto_play_timer: Timer
var _speed_index: int = 1  # Default ×1.0

@onready var play_btn: TextureButton = $Panel/VBox/RowMargin/Row/CenterGroup/PlayBtn
@onready var pause_btn: TextureButton = $Panel/VBox/RowMargin/Row/CenterGroup/PauseBtn
@onready var speed_btn: Button = $Panel/VBox/RowMargin/Row/SpeedWrap/SpeedBtn
@onready var progress_fill: ProgressBar = _resolve_progress_fill()


func _ready() -> void:
	_auto_play_timer = Timer.new()
	_auto_play_timer.wait_time = _BASE_INTERVAL
	_auto_play_timer.timeout.connect(_on_auto_play_tick)
	add_child(_auto_play_timer)

	get_viewport().size_changed.connect(func(): call_deferred("_snap_to_bottom_center"))
	call_deferred("_snap_to_bottom_center")


func _resolve_progress_fill() -> ProgressBar:
	var progress_node := get_node_or_null("Panel/UIOverlay/ProgressFill") as ProgressBar
	if progress_node == null:
		# Backward compatibility with older scene layout.
		progress_node = get_node_or_null("Panel/VBox/ProgressFill") as ProgressBar
	return progress_node


func _snap_to_bottom_center() -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(
		roundf(vp.x / 2.0 - size.x / 2.0),
		vp.y - size.y - 24.0
	)


# ──────────────────────────────────────────────────────────
#  Button handlers
# ──────────────────────────────────────────────────────────

func _on_stop_pressed() -> void:
	set_auto_playing(false)
	stop.emit()


func _on_back_pressed() -> void:
	set_auto_playing(false)
	step_back.emit()


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_pause_pressed() -> void:
	set_auto_playing(false)


func _on_forward_pressed() -> void:
	set_auto_playing(false)
	step_forward.emit()


func _on_auto_play_tick() -> void:
	step_forward.emit()


func _on_speed_btn_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()


# ──────────────────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────────────────

## Toggle auto-play on or off. Called externally when algorithm end is reached.
func set_auto_playing(playing: bool) -> void:
	_playing = playing
	play_btn.visible = not playing
	pause_btn.visible = playing
	if playing:
		_auto_play_timer.start()
	else:
		_auto_play_timer.stop()


func is_auto_playing() -> bool:
	return _playing


## Update the thin fill bar. progress is 0–100.
func set_algorithm_progress(progress: int) -> void:
	if progress_fill == null:
		return
	progress = clampi(progress, 0, 100)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(progress_fill, "value", progress, 0.14)


func set_step_info(_current: int, _max_steps: int) -> void:
	pass


## Reset all display state (called when algorithm is cancelled).
func reset() -> void:
	set_auto_playing(false)
	progress_fill.value = 0
	_speed_index = 1
	_apply_speed()


# ──────────────────────────────────────────────────────────
#  Helpers
# ──────────────────────────────────────────────────────────

func _apply_speed() -> void:
	var spd: float = SPEEDS[_speed_index]
	_auto_play_timer.wait_time = _BASE_INTERVAL / spd
	if is_equal_approx(spd, roundf(spd)):
		speed_btn.text = "%dx" % int(roundf(spd))
	else:
		speed_btn.text = "%.1fx" % spd
