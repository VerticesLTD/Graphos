## Debounced auto-save service.
##
## Emits save_requested after the scene has been quiet for delay_seconds.
## Callers mark_dirty() on any state change; this node coalesces rapid changes
## into a single save, exactly like Excalidraw's debounced onChange handler.
##
## Usage:
##   var svc := AutoSaveService.new()
##   add_child(svc)
##   svc.save_requested.connect(_do_save)
##   CommandManager.state_changed.connect(svc.mark_dirty)
extends Node
class_name AutoSaveService

signal save_requested

@export var delay_seconds: float = 2.0

var _timer: Timer
var _paused: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


## Restart the quiet-period countdown. Has no effect while paused.
func mark_dirty() -> void:
	if _paused:
		return
	_timer.start(delay_seconds)


## Pause auto-save (e.g. while restoring a document to avoid saving partial state).
func pause() -> void:
	_paused = true
	_timer.stop()


## Resume auto-save after a load or other bulk operation.
func resume() -> void:
	_paused = false


func _on_timer_timeout() -> void:
	save_requested.emit()
