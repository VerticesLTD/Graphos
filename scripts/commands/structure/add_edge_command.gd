## Command to add an edge between two vertices.
## This class captures the state required to apply and revert an edge addition.
class_name AddEdgeCommand
extends Command

var from_id: int
var to_id: int
var weight: int

## Initializes the add edge command.
## @param w     The weight of the new edge (defaults to 1).
func _init(g: Graph, src_id: int, dst_id: int, w: int = 1):
	super(g)
	from_id = src_id
	to_id = dst_id
	weight = w

func execute() -> void:
	# Tells the graph to connect these two specific IDs with the stored weight
	graph.add_edge(from_id, to_id, weight)

func undo() -> void:
	# Tells the graph to break the connection between these two IDs
	graph.delete_edge(from_id, to_id)
