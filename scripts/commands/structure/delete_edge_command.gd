## Command to remove an edge between two vertices.
## This class captures all edge properties (strategy, weight, flags) before deletion 
## to ensure a perfect restoration during Undo.
class_name DeleteEdgeCommand
extends Command

var from_id: int
var to_id: int
var previous_weight: float

# Properties required to restore the edge's identity
var strategy: ConnectionStrategy
var is_weighted: bool

# Safety flag to prevent execution if the edge doesn't exist
var is_valid: bool = false

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
		strategy = edge.strategy
		is_weighted = edge.is_weighted
		is_valid = true
	else:
		# Log the issue for debugging but keep the app running
		Notify.show_error("Edge Error: Attempted to delete non-existent edge.")
		is_valid = false

func execute() -> void:
	if not is_valid: return
	graph.delete_edge(from_id, to_id)

func undo() -> void:
	if not is_valid: return
	# Restoration preserves the exact original Strategy and Weighted state
	graph.add_edge(from_id, to_id, previous_weight, strategy, is_weighted, true)
