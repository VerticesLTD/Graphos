## Holds a stack of commands and executes/redoes them. Singleton.
extends Node

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

## execute one command
func execute(cmd: Command) -> void:
	cmd.execute()
	undo_stack.append(cmd)
	# IMPORTANT: If the user does a NEW action, you must clear the redo stack.
	# You can't redo into a "branching" timeline.
	redo_stack.clear()

## Reverse the last action
func undo() -> void:
	if undo_stack.is_empty(): return
	
	var cmd = undo_stack.pop_back()
	cmd.undo()
	redo_stack.append(cmd) # Move it here so we can "Redo" it

## Re-apply the last undone action
func redo() -> void:
	if redo_stack.is_empty(): return
	
	var cmd = redo_stack.pop_back()
	cmd.execute() # Run the logic again
	undo_stack.append(cmd) # Put it back on the undo stack
		
## Push new command to stack
func push_to_stack(cmd) -> void:
	undo_stack.append(cmd)
