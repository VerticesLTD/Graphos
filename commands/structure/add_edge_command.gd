## Command to add an edge between two vertices.
## This class captures the state required to apply and revert an edge addition.
class_name AddEdgeCommand
extends Command

var from_id: int
var to_id: int
var weight: float
var strategy: ConnectionStrategy
var is_weighted: bool
var edge_color: Color = Globals.EDGE_COLOR
## True when this edge comes from preset/clipboard paste.
var from_clipboard_paste: bool = false

## Initializes the command. If s or w_mode are null, it snapshots Globals.
func _init(
		g: Graph,
		src_id: int,
		dst_id: int,
		w: float = 1.0,
		s: ConnectionStrategy = null,
		w_mode = null,
		_edge_color: Color = Globals.EDGE_COLOR,
		_from_clipboard_paste: bool = false
	):
	super(g)
	from_id = src_id
	to_id = dst_id
	weight = w
	edge_color = _edge_color
	from_clipboard_paste = _from_clipboard_paste

	# If a strategy/weight is provided, use it.
	# Otherwise, snapshot the current tool in the player's hand.
	strategy = s if s else Globals.active_strategy
	is_weighted = w_mode if w_mode != null else Globals.is_weighted_mode

func execute() -> void:
	graph.add_edge(from_id, to_id, weight, strategy, is_weighted, true)
	_apply_edge_color_to_adjacency()

func _apply_edge_color_to_adjacency() -> void:
	var v_src = graph.get_vertex(from_id)
	var v_dst = graph.get_vertex(to_id)
	if v_src == null or v_dst == null:
		return
	var e1 = graph.get_edge(v_src, v_dst)
	if e1:
		e1.color = edge_color
	var e2 = graph.get_edge(v_dst, v_src)
	if e2:
		e2.color = edge_color

func undo() -> void:
	var v_src = graph.get_vertex(from_id)
	var v_dst = graph.get_vertex(to_id)
	if v_src and v_dst:
		strategy.delete_edge(graph, v_src, v_dst)
