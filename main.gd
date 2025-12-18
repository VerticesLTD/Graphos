extends Node2D

func _ready() -> void:
	var graph = UndirectedGraph.new()
	add_child(graph)

	graph.add_vertex(0,Vector2(200,200),Color.GREEN)
	graph.add_vertex(1,Vector2(350,200),Color.GREEN)
	graph.add_vertex(2,Vector2(200,350),Color.GREEN)

	graph.add_edge(0,1)
	graph.add_edge(1,2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Every frame we ask the engine to redraw.
	pass

# Called by the engine for each `queue_redraw()`.
# `queue_redraw()` may be called manually (by us), but also by the engine.
func _draw() -> void:
	pass
