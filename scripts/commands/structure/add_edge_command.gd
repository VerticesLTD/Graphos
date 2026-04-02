## Command to add an edge between two vertices.
## This class captures the state required to apply and revert an edge addition.
class_name AddEdgeCommand
extends Command

var from_id: int
var to_id: int
var weight: float
var strategy: ConnectionStrategy
var is_weighted: bool

## Initializes the command. If s or w_mode are null, it snapshots Globals.
func _init(g: Graph, src_id: int, dst_id: int, w: float = 1.0, s: ConnectionStrategy = null, w_mode = null):
	super(g)
	from_id = src_id
	to_id = dst_id
	weight = w
	
	# If a strategy/weight is provided, use it.
	# Otherwise, snapshot the current tool in the player's hand.
	strategy = s if s else Globals.active_strategy
	is_weighted = w_mode if w_mode != null else Globals.is_weighted_mode

func execute() -> void:
	graph.add_edge(from_id, to_id, weight, strategy, is_weighted, true)

func undo() -> void:
	var v_src = graph.get_vertex(from_id)
	var v_dst = graph.get_vertex(to_id)
	if v_src and v_dst:
		strategy.delete_edge(graph, v_src, v_dst)
