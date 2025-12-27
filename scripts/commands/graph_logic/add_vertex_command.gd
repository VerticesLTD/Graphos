## Represents an action where a vertex changes its visual color.
## This class captures the state required to apply and revert a vertex color change action.
class_name AddVertexCommand
extends Command

## The position to add the vertex in
var pos: Vector2

## The vertex we've added, saved for undo
var vertex: Vertex

## Initializes the add vertex command.
## @param vertex     The vertex being created.
func _init(g: UndirectedGraph, mouse_pos: Vector2):
	super(g)
	pos = mouse_pos


## Executes the forward action.
## Changes the vertex's color to new_color 
func execute() -> void:
	if vertex == null:
		# First time execution: create the vertex
		vertex = graph.add_vertex(pos)
	else:
		# Redo: Re-add the exact same vertex object to the graph
		graph.add_vertex_object(vertex)
	

## Reverts the action.
## Restores the original color of the vertex.
func undo() -> void:
	if vertex:
		graph.delete_vertex(vertex)
