extends HBoxContainer

@onready var lock_tool: Button = $LockTool
@onready var create: Button = $Create
@onready var algorithm: Button = $Algorithm
@onready var eraser: Button = $Eraser
@onready var selection: Button = $Selection

# Keep track of the last state so we only animate when it changes
var _last_state = null 

func _process(_delta: float) -> void:
	# Check if the state has changed since the last frame
	if Globals.current_state != _last_state:
		_animate_buttons(Globals.current_state)
		_last_state = Globals.current_state

func _animate_buttons(current_state) -> void:
	var tween = create_tween().set_parallel(true) # Run all animations at once
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # Smooth "pop" effect
	
	var state_to_button = {
		Globals.State.CREATE: create,
		Globals.State.SELECTION: selection,
		Globals.State.ALG: algorithm,
		Globals.State.ERASER: eraser
	}
	
	var active_button = state_to_button.get(current_state)
	
	for btn in state_to_button.values():
		var target_modulate
		var target_scale
		
		if btn == active_button:
			target_modulate = Globals.BUTTON_HIGHLIGHT_MODULATE
			target_scale = Globals.BUTTON_HIGHLIGHT_SCALE
		else:
			target_modulate = Globals.BUTTON_REGULAR_MODULATE
			target_scale = Globals.BUTTON_REGULAR_SCALE
			
		tween.tween_property(btn, "modulate", target_modulate, 0.2)
		tween.tween_property(btn, "scale", target_scale, 0.2)
