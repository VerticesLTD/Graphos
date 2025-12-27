## Represents an action where a vertex changes its key.
## This class captures the state required to apply and revert a key action.
class_name ChangeVertexKeyAction
extends Action

## The target vertex of the action.
var target_vertex: Vertex

## The key to apply during forward execution.
var new_key: int

## The original key stored for undo operations.
var old_key: int

## Initializes the key change event with the necessary state snapshots.
## @param target_vertex   The vertex being modified.
## @param target_key    The new key to apply.
## @param previous_key  The current key (saved for undo).
func _init(vertex: Vertex, target_key: int, previous_key: int):
	target_vertex = vertex
	new_key = target_key
	old_key = previous_key

## Executes the forward action.
## Changes the vertex's key to new_key 
func execute() -> void:
	target_vertex.key = new_key 
	# draw
	
## Reverts the action.
## Restores the original key of the vertex.
func undo() -> void:
	target_vertex.key = old_key 
