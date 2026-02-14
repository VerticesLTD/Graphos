extends HBoxContainer

@onready var lock_tool: Button = $LockTool
@onready var create: Button  = $Create
@onready var selection: Button = $Selection

@onready var _buttons_by_state: Dictionary = {
	Globals.State.CREATE: create,
	Globals.State.SELECTION: selection,
}

# Keep track of the last state so we only animate when it changes
var _last_state = null 

func _ready() -> void:
	for btn in _buttons_by_state.values():
		_setup_button_pivot(btn)

func _setup_button_pivot(btn:Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2.0)

func _process(_delta: float) -> void:
	# Check if the state has changed since the last frame
	if Globals.current_state != _last_state:
		_animate_buttons(Globals.current_state)
		_last_state = Globals.current_state

func _animate_buttons(current_state) -> void:
	var tween = create_tween().set_parallel(true) # Run all animations at once
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # Smooth "pop" effect
	
	var active_button = _buttons_by_state.get(current_state)
	
	for btn:Button in _buttons_by_state.values():
		var is_active: bool = (btn == active_button)
		
		# Use self_modulate to tint the texture without affecting children (if any)
		# Or stick to modulate if you want the whole control tinted
		var target_modulate: Color = Globals.BUTTON_HIGHLIGHT_MODULATE if is_active else Globals.BUTTON_REGULAR_MODULATE
		var target_scale: Vector2 = Globals.BUTTON_HIGHLIGHT_SCALE if is_active else Globals.BUTTON_REGULAR_SCALE
		if is_active:
			btn.set_pressed_no_signal(true)
		else:
			btn.set_pressed_no_signal(false)
		
		tween.tween_property(btn.get_child(-1,true), "modulate", target_modulate, 0.2)
		tween.tween_property(btn, "scale", target_scale, 0.2)
