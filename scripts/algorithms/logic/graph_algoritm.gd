## GraphAlgorithm class is used as a parent class for any graph algorithm.
@abstract class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color(0.9, 0.9, 0.9)  # Off-white / Pearl
const COLOR_VISITING       = Color(0.3, 0.6, 0.9)  # Soft Sky Blue
const COLOR_FINISHED       = Color(0.2, 0.2, 0.2)  # Charcoal (Softer Black)
const COLOR_EDGE_PATH      = Color(0.40, 0.75, 1.00) # Bright Blue for the "Tree"

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var imposter_graph: Graph

## The graph as an adjacency list.(if we add diff types of graphs, we can generelize this)
var real_graph: Graph

## timeline to record the algorithm.
## A null value represents a step in the pseudo code with no Command equivilent.
var timeline: Array[Command] = []

## Array representing the related pseudo steps. Must be zero-indexed.
## A null value represents a step in the timeline with no pseudo equivilent.
var pseudo_steps: Array = []

## Set the algorithm variables
func set_alg_variables(_imposter_graph: Graph, _real_graph: Graph) -> void:
	imposter_graph = _imposter_graph
	real_graph = _real_graph

func verify_initialization() -> void:
	assert(imposter_graph != null and real_graph != null,
	"Algorithm doesn't have its variables set. Did you call set_alg_variables?")

	assert(timeline.is_empty() and pseudo_steps.is_empty(),
		"Algorithm timeline and steps aren't empty at start." +
		" This could be because the implementatin doesn't reset data at the end of run")

func _reset_alg_variables() -> void:
	imposter_graph = null
	real_graph = null
	timeline.clear()
	pseudo_steps.clear()

## Every graph algorithm must have a run function.
## Every graph algorithm has a start node, and needs to return an array.
## The array MUST be strctures as so:
## [<TIMELINE_ARRAY>,<PSEUDO_STEPS_ARRAY>,<VISUAL_DATA_ARRAY>]
## <TIMELINE_ARRAY> - This is the array containing the steps affecting the graph itself.
## <PSEUDO_STEPS_ARRAY> - This is the array containing numbers representing pseudo steps to render.
## <VISUAL_DATA_ARRAY> - This array contains updates to the graph controls, for example the current amount of processed vertices.
## Each of these arrays can contain nulls, representing a step with no logical action for the category.
## It obviously doesn't make sense for all 3 to have null at the same index.
@abstract func run(_start_vertex: Vertex) -> Array

	
# ------------------------------------------------------------------------------
# Logging Helper Functions
# ------------------------------------------------------------------------------

## Append a step to the pseudo step array.
## int for step to be rendered, null for rendering to stay the same.
func log_pseudo_step(step, add_null_to_timeline = false) -> void:
	pseudo_steps.append(step)

	if add_null_to_timeline:
		timeline.append(null)

## Changes a vertex color and records the Command in the timeline.
func change_and_log_vertex_color(target_vertex: Vertex, target_color: Color, pseudo_step = null) -> void:
	var real_v = real_graph.get_vertex(target_vertex.id)
	
	if real_v:
		timeline.append(ChangeVertexColorCommand.new(real_v, target_color))
		
	target_vertex.color = target_color

	log_pseudo_step(pseudo_step)

## Changes an edge color and records the Command in the timeline.
func change_and_log_edge_color(target_edge: Edge, target_color: Color, pseudo_step = null) -> void:
	# Get the real vertices using the IDs from the imposter edge
	var real_src = real_graph.get_vertex(target_edge.src.id)
	var real_dst = real_graph.get_vertex(target_edge.dst.id)
	
	# Find the edge that goes EXACTLY from src to dst
	# This works for both:
	# - Undirected: It finds the one shared edge.
	# - Directed: It finds the specific arrow for this direction.
	var real_edge = real_graph.get_edge(real_src, real_dst)
	
	if real_edge:
		timeline.append(ChangeEdgeColorCommand.new(real_edge, target_color))
	
	# Update the imposter for algorithm logic
	target_edge.color = target_color
	log_pseudo_step(pseudo_step)
	
## Changes a vertex key and records the Command in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: float, pseudo_step = null) -> void:
	var real_vertex = real_graph.get_vertex(target_vertex.id)
	
	if real_vertex:
		timeline.append(ChangeVertexKeyCommand.new(real_vertex, target_key))
	
	target_vertex.key = target_key

	log_pseudo_step(pseudo_step)
