## Base class for all commands.
## Acts as an abstract "Interface" - do not use this class directly.
## Instead, create child classes (like "add_edge_command") that extend this one.
extends RefCounted
class_name Command

## Pass the = null graph because the command needs it for the change
var graph: Graph

## Determines if this command should be added to the Undo Stack
var add_to_history: bool = true

## When true, this command was created by an algorithm timeline and is allowed
## to run on locked vertices/edges (algorithm playback must never be blocked).
var bypass_lock: bool = false

## Initialize the command, make Graph null in def so its optional.
func _init(_graph: Graph = null):
	self.graph = _graph
	
## Performs the action (Forward).
## This function must be overridden by the child class.
func execute() -> void:
	push_error("execute() method not implemented in " + get_script().resource_path)

## Reverts the action (Backward).
## This function must be overridden by the child class.
func undo() -> void:
	push_error("undo() method not implemented in " + get_script().resource_path)
