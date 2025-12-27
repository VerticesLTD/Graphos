## Holds a stack of commands and executes/redoes them.
extends Node

## The command stack
var undo_stack: Array[Command] = []

## execute one command
func execute(cmd: Command) -> void:
	cmd.execute()
	undo_stack.append(cmd)

## Undo one command
func undo() -> void:
	if not undo_stack.is_empty():
		undo_stack.pop_back().undo()
