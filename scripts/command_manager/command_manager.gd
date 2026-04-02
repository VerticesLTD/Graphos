## Holds a stack of commands and executes/redoes them. Singleton.
extends Node

signal history_changed

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

## execute one command
func execute(cmd: Command) -> void:
	cmd.execute()
	
	if cmd.add_to_history:
		undo_stack.append(cmd)
		redo_stack.clear()

## Reverse the last action
func undo() -> void:
	if undo_stack.is_empty(): return
	
	var cmd = undo_stack.pop_back()
	cmd.undo()
	redo_stack.append(cmd)
	history_changed.emit()

## Re-apply the last undone action
func redo() -> void:
	if redo_stack.is_empty(): return
	
	var cmd = redo_stack.pop_back()
	cmd.execute() 
	undo_stack.append(cmd)
	history_changed.emit()

## Push new command to stack
func push_to_stack(cmd) -> void:
	if cmd.add_to_history:
		undo_stack.append(cmd)
		redo_stack.clear()
