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
	# TEST:
# 	1. Setup the Components
	# We create the visualizer and add it to the scene tree so it "exists".
	var my_visualizer = GraphVisualizer.new()
	add_child(my_visualizer)
	
	# We create the manager and give it the visualizer
	var manager = EventManager.new(my_visualizer)
	
	print("1. Components Created Successfully.")
	
	# 2. Create events:
	# Event A: Change Node 1 from White to Red
	var event_a = EventChangeVertexColor.new(1, Color.RED, Color.WHITE)
	# Event B: Change Node 2 from White to Blue
	var event_b = EventChangeVertexColor.new(2, Color.BLUE, Color.WHITE)
	
	# 3. Record them to the timeline
	manager.add_event(event_a)
	manager.add_event(event_b)
	
	print("2. Recorded 2 Events. Timeline size: ", manager.timeline.size())
	
	# 4. Test Playback (Forward)
	print("\n--- Testing Step Forward ---")
	manager.step_forward() # Should make Node 1 RED
	manager.step_forward() # Should make Node 2 BLUE
	
	# 5. Test Undo (Backward)
	print("\n--- Testing Step Backward ---")
	manager.step_backward() # Should make Node 2 WHITE (Undo)
	
	# 6. Test Reset
	print("\n--- Testing Reset ---")
	manager.reset_to_start() # Should make Node 1 WHITE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Every frame we ask the engine to redraw.
	queue_redraw()

# Called by the engine for each `queue_redraw()`.
# `queue_redraw()` may be called manually (by us), but also by the engine.
func _draw() -> void:
	for circle in CIRCLES:
		draw_custom_circle(circle)
