## GraphAlgorithm class is used as a parent class for any graph algorithm.
@abstract class_name GraphAlgorithm

## Define consts for the algorithms vertices's state.
const COLOR_NOT_DISCOVERED = Color(0.62, 0.64, 0.74)    # Undiscovered
const COLOR_VISITING       = Color(0.263, 0.38, 0.933)  # Discovered / frontier
const COLOR_FINISHED       = Color(0.149, 0.651, 0.604) # Finished
const COLOR_EDGE_PATH      = Color(0.263, 0.38, 0.933)  # Traversal edge

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

## Returns a dictionary declaring what this algorithm requires from the graph.
## Supported keys:
##   "directed"            : bool — true = must be directed, false = must be undirected
##   "weighted"            : bool — true = must be weighted,  false = must be unweighted
##   "no_negative_weights" : bool — true = no edge may have a negative weight (use for algorithms
##                            where negatives break correctness, e.g. Dijkstra; not needed for Prim/MST)
##   "warn_if_weighted"    : bool — if true, show an info notification when the graph is weighted (e.g. BFS/DFS ignore weights)
## Omitting a key means the algorithm has no requirement for that property.
func get_requirements() -> Dictionary:
	return {}

## Whether this algorithm should render per-vertex key badges.
## Override in algorithms such as Dijkstra or Prim that rely on keys.
func requires_vertex_keys_display() -> bool:
	return false

## Validates graph against the base integrity rules and this algorithm's requirements.
## Shows a Notify error and returns false on the first violation. May show an informational notification (e.g. traversal on weighted graphs).
func check_requirements(graph: Graph) -> bool:
	# --- Always: mixed directed/undirected guard ---
	var dominant_strategy := graph.get_graph_dominant_strategy()
	if graph.num_edges > 0 and dominant_strategy == null:
		Notify.show_error("Mixed directionality: algorithms require one edge type. Use right-click \u2192 Change Direction on a selection to unify edges.")
		return false

	# --- Always: mixed weighted/unweighted guard ---
	var weight_state = graph.get_graph_weight_state()
	if weight_state == null:
		Notify.show_error("Mixed weights: algorithms require either all weighted or all unweighted edges. Use right-click \u2192 Weight on a selection to unify edges.")
		return false

	var reqs := get_requirements()

	# --- Per-algorithm: directed / undirected ---
	if reqs.has("directed") and dominant_strategy != null:
		var needs_directed: bool = reqs["directed"]
		if needs_directed and not (dominant_strategy is DirectedStrategy):
			Notify.show_error("%s requires a directed graph." % get_script().resource_path.get_file().get_basename())
			return false
		if not needs_directed and not (dominant_strategy is UndirectedStrategy):
			Notify.show_error("%s requires an undirected graph." % get_script().resource_path.get_file().get_basename())
			return false

	# --- Per-algorithm: weighted / unweighted ---
	if reqs.has("weighted"):
		var needs_weighted: bool = reqs["weighted"]
		if needs_weighted and weight_state != "weighted":
			Notify.show_error("%s requires a weighted graph." % get_script().resource_path.get_file().get_basename())
			return false
		if not needs_weighted and weight_state != "unweighted":
			Notify.show_error("%s requires an unweighted graph." % get_script().resource_path.get_file().get_basename())
			return false

	# --- Per-algorithm: info when graph is weighted but algorithm ignores weights (e.g. BFS/DFS) ---
	if reqs.get("warn_if_weighted", false) and weight_state == "weighted":
		var alg_name: String = get_script().resource_path.get_file().get_basename()
		Notify.show_notification("%s ignores edge weights; only adjacency affects the traversal." % alg_name)

	# --- Per-algorithm: no negative weights ---
	if reqs.get("no_negative_weights", false):
		for v: Vertex in graph.vertices.values():
			for edge: Edge in v.get_outgoing_edges():
				if edge.is_weighted and edge.weight < 0:
					Notify.show_error("%s does not support negative edge weights." % get_script().resource_path.get_file().get_basename())
					return false

	return true

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
	else:
		# Keep timeline length aligned with pseudo_steps when the real edge is missing.
		timeline.append(null)
	
	# Update the imposter for algorithm logic
	target_edge.color = target_color
	log_pseudo_step(pseudo_step)

## Discovers a vertex through an edge as ONE visual/timeline step.
## Applies edge flow animation first (via command), then edge+vertex colors together.
func discover_vertex_via_edge_and_log(
	target_edge: Edge,
	target_vertex: Vertex,
	target_edge_color: Color,
	target_vertex_color: Color,
	pseudo_step = null
) -> void:
	var real_src = real_graph.get_vertex(target_edge.src.id)
	var real_dst = real_graph.get_vertex(target_edge.dst.id)
	var real_vertex = real_graph.get_vertex(target_vertex.id)
	var real_edge = real_graph.get_edge(real_src, real_dst)

	if real_edge and real_vertex:
		timeline.append(
			DiscoverVertexViaEdgeCommand.new(
				real_edge,
				real_vertex,
				target_edge_color,
				target_vertex_color
			)
		)

	target_edge.color = target_edge_color
	target_vertex.color = target_vertex_color
	log_pseudo_step(pseudo_step)
	
## Changes a vertex key and records the Command in the timeline.
func change_and_log_vertex_key(target_vertex: Vertex, target_key: float, pseudo_step = null) -> void:
	var real_vertex = real_graph.get_vertex(target_vertex.id)
	
	if real_vertex:
		timeline.append(ChangeVertexKeyCommand.new(real_vertex, target_key))
	
	target_vertex.key = target_key

	log_pseudo_step(pseudo_step)

## Colors ALL vertices in the algorithm graph as ONE logged timeline step.
## Use for initialization so undo naturally restores original colors.
func log_initialize_vertices(color: Color, pseudo_step = null) -> void:
	var real_vertices: Array[Vertex] = []
	for v: Vertex in imposter_graph.vertices.values():
		v.color = color
		v.parent = null
		var real_v := real_graph.get_vertex(v.id)
		if real_v:
			real_vertices.append(real_v)
	timeline.append(ChangeSelectionVertexColorCommand.new(real_vertices, color))
	log_pseudo_step(pseudo_step)

## Sets each vertex to its own color in ONE timeline step (e.g. Kruskal make-set).
func change_and_log_vertices_per_vertex_colors(imposter_vertices: Array[Vertex], new_colors: Array[Color], pseudo_step = null) -> void:
	assert(imposter_vertices.size() == new_colors.size())
	var real_vertices: Array[Vertex] = []
	var filtered_colors: Array[Color] = []
	for i in range(imposter_vertices.size()):
		var iv: Vertex = imposter_vertices[i]
		var rv: Vertex = real_graph.get_vertex(iv.id)
		iv.color = new_colors[i]
		if rv:
			real_vertices.append(rv)
			filtered_colors.append(new_colors[i])
	if not real_vertices.is_empty():
		timeline.append(ChangeVerticesPerVertexColorCommand.new(real_vertices, filtered_colors))
	log_pseudo_step(pseudo_step)
