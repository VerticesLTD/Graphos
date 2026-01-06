extends MarginContainer


## Should let the user stay in the tool it's currently using
func _on_lock_tool_pressed() -> void:
	pass # Replace with function body.


func _on_selection_pressed() -> void:
	Globals.current_state = Globals.State.SELECTION


func _on_create_pressed() -> void:
	Globals.current_state = Globals.State.CREATE


func _on_algorithm_pressed() -> void:
	Globals.current_state = Globals.State.ALG


func _on_eraser_pressed() -> void:
	Globals.current_state = Globals.State.ERASER
