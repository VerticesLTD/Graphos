## GraphAlgorithm class is used as a parent class for any graph algorithm.
class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color(0.9, 0.9, 0.9)  # Off-white / Pearl
const COLOR_VISITING       = Color(0.3, 0.6, 0.9)  # Soft Sky Blue
const COLOR_FINISHED       = Color(0.2, 0.2, 0.2)  # Charcoal (Softer Black)
const COLOR_EDGE_PATH      = Color(0.40, 0.75, 1.00) # Bright Blue for the "Tree"

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
	var real_v = real_graph.get_vertex(target_vertex.id)
	
	if real_v:
		timeline.append(ChangeVertexColorCommand.new(real_v, target_color))
		
	target_vertex.color = target_color

## Changes an edge color and records the Command in the timeline.
## Changes an edge color and records the Command in the timeline.
func change_and_log_edge_color(target_edge: Edge, target_color: Color) -> void:
	# 1. Normalize the IDs to find the 'Real' (shouting) edge
	var u_id = target_edge.src.id
	var v_id = target_edge.dst.id
	
	var lower_id = u_id if u_id < v_id else v_id
	var higher_id = v_id if u_id < v_id else u_id
	
	# 2. Get the actual vertices from the REAL graph
	var real_src = real_graph.get_vertex(lower_id)
	var real_dst = real_graph.get_vertex(higher_id)
	
	# 3. Find the edge that actually owns the Visual Sprite
	var real_edge = real_graph.get_edge(real_src, real_dst)
	
	if real_edge:
		# Record the command targeting the visual edge
		timeline.append(ChangeEdgeColorCommand.new(real_edge, target_color))
	
	# Update the imposter edge so the algorithm's state stays consistent
	target_edge.color = target_color
	
## Changes a vertex key and records the Command in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: float) -> void:
	var previous_key = target_vertex.key
	var real_vertex = real_graph.get_vertex(target_vertex.id)
	
	if real_vertex:
		timeline.append(ChangeVertexKeyCommand.new(real_vertex, target_key, previous_key))
	
	target_vertex.key = target_key
