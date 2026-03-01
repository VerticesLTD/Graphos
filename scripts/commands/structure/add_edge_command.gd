## Represents an action where a vertex changes its visual color.
## This class captures the state required to apply and revert a vertex color change action.
class_name AddEdgeCommand
extends Command

var from_id: int
var to_id: int

## Initializes the add vertex command.
## @param vertex     The vertex being created.
func _init(g: Graph, src_id: int, dst_id: int):
	super(g)
	from_id = src_id
	to_id = dst_id

func execute() -> void:
	# Tells the graph to connect these two specific IDs
	graph.add_edge(from_id, to_id)

func undo() -> void:
	# Tells the graph to break the connection between these two IDs
	graph.delete_edge(from_id, to_id)
