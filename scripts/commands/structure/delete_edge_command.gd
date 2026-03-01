## Command to remove an edge between two vertices.
## This class captures all edge properties (strategy, weight, flags) before deletion 
## to ensure a perfect restoration during Undo.
class_name DeleteEdgeCommand
extends Command

var from_id: int
var to_id: int
var previous_weight: int

# Properties required to restore the edge's identity
var strategy: ConnectionStrategy
var is_weighted: bool

## Initializes the delete edge command.
func _init(g: Graph, src_id: int, dst_id: int):
	super(g)
	from_id = src_id
	to_id = dst_id
	
	# Fetch the edge before we delete it to save its full state
	var v_src = graph.get_vertex(src_id)
	var v_dst = graph.get_vertex(dst_id)
	var edge = graph.get_edge(v_src, v_dst)
	
	if edge:
		previous_weight = edge.weight
		# Store the edge's internal sandbox data
		strategy = edge.strategy
		is_weighted = edge.is_weighted
	else:
		# TBD: Throw error?
		previous_weight = 1
		strategy = Globals.active_strategy
		is_weighted = Globals.is_weighted_mode

func execute() -> void:
	graph.delete_edge(from_id, to_id)

func undo() -> void:
	graph.add_edge(from_id, to_id, previous_weight, strategy, is_weighted, true)
