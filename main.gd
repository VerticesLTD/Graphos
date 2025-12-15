extends Node2D

# An inner class. Think of it as a struct. For big classes, it is better to create a separate file
# and use the `class_name` keyword
class Circle:
	var position:Vector2
	var radius:float
	var color:Color

	func _init(pos:Vector2, r:float, c:Color) -> void:
		self.position = pos
		self.radius = r
		self.color = c

# A function that takes a circle and calls `draw_circle()` with it's data.
# `draw_circle()` Can only be called inside `_draw()`, as it is a drawing function.
func draw_custom_circle(circle:Circle):
	draw_circle(circle.position,circle.radius,circle.color,true,-1.0,true)
	

var CIRCLES = [
	Circle.new(Vector2(300,300),20,Color.YELLOW),
	Circle.new(Vector2(300,400),20,Color.BLUE),
	Circle.new(Vector2(200,300),20,Color.GREEN),
	]

# Called when the node enters the scene tree for the first time.
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
	queue_redraw()

# Called by the engine for each `queue_redraw()`.
# `queue_redraw()` may be called manually (by us), but also by the engine.
func _draw() -> void:
	for circle in CIRCLES:
		draw_custom_circle(circle)
