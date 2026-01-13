## Command to execute an algorithm based on a starting vertex and the algorithm name
class_name ExecuteAlgorithm
extends Command

var algo_class: GDScript
var start_v: Vertex
var selection_buffer: Array[Vertex]
var controller: Node # Reference to GraphController


func _init(_algo_class: GDScript, _start_node: Vertex, 
		_selection_buffer: Array[Vertex], 
		_graph: UndirectedGraph, _controller: Node):
	super(_graph)
	algo_class = _algo_class
	start_v = _start_node
	selection_buffer = _selection_buffer
	controller = _controller	
		
func execute() -> void:
	## This function can now run BFS, DFS, Dijkstra, or any future algorithm.
	## @param algo_class: The Script/Class of the algorithm (e.g., BFS)
	## @param start_node: The real vertex where we want to begin

	# 1. Create the Imposter Graph (The Sandbox)
	# Pass the selection buffer to run the algo on the sub-graph
	var imposter_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
	
	# 2. Instantiate the specific algorithm generically
	# Every child of GraphAlgorithm uses the same _init(_imposter, _real)
	var algo_instance: GraphAlgorithm = algo_class.new(imposter_graph, graph)
	
	# 3. Find the starting vertex's equivalent in the imposter graph
	var imposter_start_node = imposter_graph.get_vertex(start_v.id)
	
	# 4. RUN the algorithm to generate the timeline
	var timeline = algo_instance.run(imposter_start_node)
	
	# 5. Initialize the playback
	var new_player = AlgorithmPlayer.new(timeline)
		
	# HAND OVER the player to the controller so the UI can use it
	if controller and controller.has_method("set_algorithm_player"):
		controller.set_algorithm_player(new_player)
		
	# 6. Cleanup the imposter graph
	# The timeline already has the Commands targeting the REAL graph
	imposter_graph.queue_free()

func undo() -> void:
	# Optional: Clear the graph
	pass
