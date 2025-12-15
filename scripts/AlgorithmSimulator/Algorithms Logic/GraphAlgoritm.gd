## GraphAlgorithm class is used as a parent class for any graph algorithm.
class_name GraphAlgorithm
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
