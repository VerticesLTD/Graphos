## GraphAlgorithm class is used as a parent class for any graph algorithm.
class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color.WHITE
const COLOR_VISITING = Color.GRAY
const COLOR_FINISHED = Color.BLACK

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var imposter_graph: UndirectedGraph

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var true_graph: UndirectedGraph

## timeline to record the algorithm
var timeline: Array[Command] = []

## Initialize the algorithm
## @param undirected_graph   The graph the algorithm uses.
func _init(_imposter_graph: UndirectedGraph, _true_graph: UndirectedGraph):
	imposter_graph = _imposter_graph
	true_graph =_true_graph

## Every graph algorithm must have a run function.
## Every graph algorithm has a start node, and needs to return an array.
func run(_start_vertex: Vertex) -> Array[Command]:
	push_error("run() not implemented in child class")
	return []
	
# ------------------------------------------------------------------------------
# Logging Helper Functions
# ------------------------------------------------------------------------------

## Changes a vertex color and records the Command in the timeline.
func change_and_log_vertex_color(target_vertex: Vertex, target_color: Color) -> void:
	var previous_color = target_vertex.color
	var real_vertex_id = target_vertex.true_vertex_id
	var real_vertex = true_graph.get_vertex(real_vertex_id)
	
	if real_vertex:
		CommandManager.push_to_stack(ChangeVertexColorCommand.new(real_vertex, target_color, previous_color))
	
	target_vertex.color = target_color

## Changes an edge color and records the Command in the timeline.
func change_and_log_edge_color(target_edge: Edge, target_color: Color) -> void:
	var previous_color = target_edge.color
	
	# Mapping logic for Edges:
	# Get the real IDs from the endpoints of the imposter edge
	var real_u_id = target_edge.src.true_vertex_id
	var real_v_id = target_edge.dst.true_vertex_id
	
	var real_u_vertex = true_graph.get_vertex(real_u_id)
	var real_v_vertex = true_graph.get_vertex(real_v_id)

	
	# Find the matching edge in the real graph
	var real_edge = true_graph.get_edge(real_u_vertex, real_v_vertex)
	
	if real_edge:
		CommandManager.push_to_stack(ChangeEdgeColorCommand.new(real_edge, target_color, previous_color))
	
	target_edge.color = target_color

## Changes a vertex key and records the Command in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: float) -> void:
	var previous_key = target_vertex.key
	var real_vertex_id = target_vertex.true_vertex_id
	var real_vertex = true_graph.get_vertex(real_vertex_id)
	
	if real_vertex:
		CommandManager.push_to_stack(ChangeVertexKeyCommand.new(real_vertex, target_key, previous_key))
	
	target_vertex.key = target_key
