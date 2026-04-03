## Base class for all undoable commands.
## Do not instantiate directly — create a concrete subclass instead.
##
## ── Algorithm-lock system ───────────────────────────────────────────────────
## While an algorithm is playing, every vertex and edge it operates on is
## marked with `is_algorithm_locked = true`.  User-initiated commands must
## respect that flag and refuse to run so the algorithm's visual state stays
## coherent.
##
## Algorithm timeline commands, however, must ALWAYS be allowed through —
## they are the algorithm.  Those commands are created with `bypass_lock = true`
## so the guards below become no-ops for them.
##
## Guard usage in a concrete command's execute():
##   if _vertex_locked(my_vertex, "delete"):  return
##   if _edge_locked(my_edge,     "recolor"): return
##   if _any_vertex_locked(vertices, "delete"): return
##   if _any_edge_locked(edges,     "recolor"): return
##
## Composite commands that delegate to inner commands must propagate the flag:
##   _relay_bypass([inner_cmd_a, inner_cmd_b])
##   inner_cmd_a.execute()
##   inner_cmd_b.execute()
## ────────────────────────────────────────────────────────────────────────────
extends RefCounted
class_name Command

var graph: Graph

## When false (default), execute() respects the algorithm lock.
## Algorithm timeline commands set this to true at creation time so playback
## can never be blocked by a lock that the algorithm itself produced.
var bypass_lock: bool = false

## Whether this command is pushed onto the undo/redo stack after execution.
var add_to_history: bool = true


func _init(_graph: Graph = null) -> void:
	self.graph = _graph


## Override in subclasses to perform the action.
func execute() -> void:
	push_error("execute() not implemented in " + get_script().resource_path)


## Override in subclasses to revert the action.
func undo() -> void:
	push_error("undo() not implemented in " + get_script().resource_path)


# ── Lock guard helpers ────────────────────────────────────────────────────────
# Each helper returns true when the operation must be blocked, and shows the
# user a clear error message explaining why.  The `action` string (e.g.
# "delete", "recolor", "change weight on") is inserted into the message so
# every blocked operation gives a context-specific reason.

## Blocks a single-vertex mutation. Returns true if the call should abort.
func _vertex_locked(v: Vertex, action: String) -> bool:
	if bypass_lock or not v.is_algorithm_locked:
		return false
	Notify.show_error("Cannot %s: this vertex is part of a running algorithm." % action)
	return true


## Blocks a single-edge mutation. Returns true if the call should abort.
func _edge_locked(e: Edge, action: String) -> bool:
	if bypass_lock or not e.is_algorithm_locked:
		return false
	Notify.show_error("Cannot %s: this edge is part of a running algorithm." % action)
	return true


## Blocks a batch vertex mutation if ANY vertex is locked.
## Returns true if the call should abort.
func _any_vertex_locked(vertices: Array[Vertex], action: String) -> bool:
	if bypass_lock:
		return false
	for v in vertices:
		if v.is_algorithm_locked:
			Notify.show_error(
				"Cannot %s: the selection contains a vertex that is part of a running algorithm." % action
			)
			return true
	return false


## Blocks a batch edge mutation if ANY edge is locked.
## Returns true if the call should abort.
func _any_edge_locked(edges: Array[Edge], action: String) -> bool:
	if bypass_lock:
		return false
	for e in edges:
		if e.is_algorithm_locked:
			Notify.show_error(
				"Cannot %s: the selection contains an edge that is part of a running algorithm." % action
			)
			return true
	return false


## Copies this command's bypass_lock onto a list of inner commands before
## delegating to them.  Call this at the top of execute() and undo() in any
## composite command that wraps other commands.
func _relay_bypass(inner_commands: Array[Command]) -> void:
	for cmd in inner_commands:
		cmd.bypass_lock = bypass_lock
