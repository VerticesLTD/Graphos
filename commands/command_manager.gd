## Holds a stack of commands and executes/redoes them. Singleton.
extends Node

signal history_changed
## Emitted whenever history-tracked state changes (execute, undo, redo).
## Connect persistence systems here instead of history_changed.
signal state_changed

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

## execute one command
func execute(cmd: Command) -> void:
	cmd.execute()

	if cmd.add_to_history:
		undo_stack.append(cmd)
		redo_stack.clear()
		state_changed.emit()

## Reverse the last action
func undo() -> void:
	if undo_stack.is_empty(): return

	var cmd = undo_stack.pop_back()
	cmd.undo()
	redo_stack.append(cmd)
	history_changed.emit()
	state_changed.emit()

## Re-apply the last undone action
func redo() -> void:
	if redo_stack.is_empty(): return

	var cmd = redo_stack.pop_back()
	cmd.execute()
	undo_stack.append(cmd)
	history_changed.emit()
	state_changed.emit()

## Push an already-executed command to the history stack (e.g. live-drag moves).
func push_to_stack(cmd) -> void:
	if cmd.add_to_history:
		undo_stack.append(cmd)
		redo_stack.clear()
		state_changed.emit()

## Clear undo/redo history (called after loading a document).
func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	history_changed.emit()
