## Command to remove an edge between two vertices.
class_name DeleteEdgeCommand
extends Command

var from_id: int
var to_id: int

func _init(g: UndirectedGraph, src_id: int, dst_id: int):
	super(g)
	from_id = src_id
	to_id = dst_id

func execute() -> void:
	graph.delete_edge(from_id, to_id)

func undo() -> void:
	graph.add_edge(from_id, to_id)
