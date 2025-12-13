# Base class for all graph events.
# Acts as an abstract "Interface" - do not use this class directly.
# Instead, create child classes (like "ChangeColorEvent") that extend this one.

class_name GraphEvent
extends RefCounted # Automatically manages memory: deletes itself when no longer used (no need for queue_free).
# Godot save a counter for num times this object is saved, and when it hits 0, it auto-deletes it.
# basically similar to java garbage collector

# Performs the action (Forward).
# This function must be overridden by the child class.
func execute(visualizer: GraphVisualizer) -> void:
	push_error("execute() method not implemented in " + get_script().resource_path)

# Reverts the action (Backward).
# This function must be overridden by the child class.
func undo(visualizer: GraphVisualizer):
	push_error("undo() method not implemented in " + get_script().resource_path)
