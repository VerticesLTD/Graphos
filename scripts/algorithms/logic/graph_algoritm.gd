## GraphAlgorithm class is used as a parent class for any graph algorithm.
class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color.WHITE
const COLOR_VISITING = Color.GRAY
const COLOR_FINISHED = Color.BLACK

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var imposter_graph: UndirectedGraph

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var real_graph: UndirectedGraph

## timeline to record the algorithm
var timeline: Array[Command] = []

## Initialize the algorithm
## @param undirected_graph   The graph the algorithm uses.
func _init(_imposter_graph: UndirectedGraph, _real_graph: UndirectedGraph):
	imposter_graph = _imposter_graph
	real_graph =_real_graph

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
	var real_v = real_graph.get_vertex(target_vertex.id)
	
	if real_v:
		timeline.append(ChangeVertexColorCommand.new(real_v, target_color, previous_color))
		
	target_vertex.color = target_color

## Changes an edge color and records the Command in the timeline.
func change_and_log_edge_color(target_edge: Edge, target_color: Color) -> void:
	var previous_color = target_edge.color
	
	var real_src_v = real_graph.get_vertex(target_edge.src.id)
	var real_dst_v = real_graph.get_vertex(target_edge.dst.id)

	# Find the matching edge in the real graph
	var real_edge = real_graph.get_edge(real_src_v, real_dst_v)
	
	if real_edge:
		timeline.append(ChangeEdgeColorCommand.new(real_edge, target_color, previous_color))
	
	target_edge.color = target_color

## Changes a vertex key and records the Command in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: float) -> void:
	var previous_key = target_vertex.key
	var real_vertex = real_graph.get_vertex(target_vertex.id)
	
	if real_vertex:
		timeline.append(ChangeVertexKeyCommand.new(real_vertex, target_key, previous_key))
	
	target_vertex.key = target_key
