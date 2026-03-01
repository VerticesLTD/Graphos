## Command to add a new vertex to the graph and manage its persistence for Undo/Redo.
class_name AddVertexCommand
extends Command

var pos: Vector2
var vertex: Vertex

func _init(g: Graph, mouse_pos: Vector2):
	super(g)
	pos = mouse_pos

func execute() -> void:
	if vertex == null:
		# First time execution: create the vertex
		vertex = graph.add_vertex(pos)
	else:
		# Redo: Re-add the exact same vertex object to the graph
		graph.restore_vertex(vertex)
		
func undo() -> void:
	if vertex:
		# Removes the vertex and its connected edges from the graph data
		graph.delete_vertex(vertex)
