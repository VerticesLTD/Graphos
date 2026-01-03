## Base class for all commands.
## Acts as an abstract "Interface" - do not use this class directly.
## Instead, create child classes (like "add_edge_command") that extend this one.
extends RefCounted
class_name Command

## Pass the = null graph because the command needs it for the change
var graph: UndirectedGraph

## Initialize the command, make UndirectedGraph null in def so its optional.
func _init(_graph: UndirectedGraph = null):
	self.graph = _graph
	
## Performs the action (Forward).
## This function must be overridden by the child class.
func execute() -> void:
	push_error("execute() method not implemented in " + get_script().resource_path)

## Reverts the action (Backward).
## This function must be overridden by the child class.
func undo() -> void:
	push_error("undo() method not implemented in " + get_script().resource_path)
