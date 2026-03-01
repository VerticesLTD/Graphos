## Command to remove an edge between two vertices.
class_name DeleteEdgeCommand
extends Command

var from_id: int
var to_id: int
var previous_weight: int

func _init(g: Graph, src_id: int, dst_id: int):
	super(g)
	from_id = src_id
	to_id = dst_id
	
	# Fetch the edge before we delete it to save its weight
	var edge = graph.get_edge(graph.get_vertex(src_id), graph.get_vertex(dst_id))
	if edge:
		previous_weight = edge.weight
	else:
		previous_weight = 1 # Fallback

func execute() -> void:
	graph.delete_edge(from_id, to_id)

func undo() -> void:
	# Pass the saved weight back in. Shout naturally defaults to true!
	graph.add_edge(from_id, to_id, previous_weight)
