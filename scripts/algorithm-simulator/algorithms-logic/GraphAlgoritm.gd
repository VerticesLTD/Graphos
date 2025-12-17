## GraphAlgorithm class is used as a parent class for any graph algorithm.
class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color.WHITE
const COLOR_VISITING = Color.YELLOW
const COLOR_FINISHED = Color.GREEN

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var graph: UndirectedGraph

## timeline to record the algorithm
var timeline: Array[Action] = []

## Initialize the algorithm
## @param undirected_graph   The graph the algorithm uses.
func _init(undirected_graph: UndirectedGraph):
	graph = undirected_graph

## Every graph algorithm must have a run function.
## Every graph algorithm has a start node, and needs to return an array.
func run(_start_vertex: Vertex) -> Array[Action]:
	push_error("run() not implemented in child class")
	return []
	
# ------------------------------------------------------------------------------
# Logging Helper Functions
# ------------------------------------------------------------------------------

## Changes a vertex color and records the action in the timeline.
func change_and_log_vertex_color(target_vertex: Vertex, target_color: Color) -> void:
	var previous_color = target_vertex.color
	timeline.append(ChangeVertexColorAction.new(target_vertex, target_color, previous_color))
	target_vertex.color = target_color

## Changes an edge color and records the action in the timeline.
func change_and_log_edge_color(target_edge: Edge, target_color: Color) -> void:
	var previous_color = target_edge.color
	timeline.append(ChangeEdgeColorAction.new(target_edge, target_color, previous_color))
	target_edge.color = target_color

## Changes a vertex key and records the action in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: int) -> void:
	var previous_key = target_vertex.key
	timeline.append(ChangeVertexKeyAction.new(target_vertex, target_key, previous_key))
	target_vertex.key = target_key
