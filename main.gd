extends Node2D

var graph = UndirectedGraph.new()

func _ready() -> void:
	test_bfs()


# In Main.gd
func test_bfs():
	var graph = UndirectedGraph.new()

	# 1. Create 5 vertices
	for i in range(1, 6):
		graph.add_vertex(i)

	# 2. Create connections
	graph.add_edge(1, 2)
	graph.add_edge(1, 3)
	graph.add_edge(2, 4)
	graph.add_edge(3, 5)

	# 3. Run the algorithm
	var bfs = BFS.new(graph)
	var start_node = graph.get_vertex(1)
	
	if start_node:
		var tape = bfs.run(start_node)
		
		# 4. Print the array as is
		print(tape)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Every frame we ask the engine to redraw.
	pass

# Called by the engine for each `queue_redraw()`.
# `queue_redraw()` may be called manually (by us), but also by the engine.
func _draw() -> void:
	pass
