## A class to control the graph, recieves inputs, and changes the graph.
extends Node
class_name GraphController

## Allows the controller to 
@onready var preview_sprite: Node2D = $"../PlacementPreview"

## Allows the controller to control the graph
@export var graph: UndirectedGraph

## Vars to handle vertex being dragged.
var dragged_vertex_id: int = Globals.NOT_FOUND
var is_dragging: bool = false

# The selection buffer needs to live here to track the current input path
var selection_buffer: Array[int] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Gives the Controller the ability to 'catch' the input
	InputHandler.subscribe_to_intention(InputHandler.INTENTION_TYPE.MOUSE_CLICK, self)
	InputHandler.subscribe_to_intention(InputHandler.INTENTION_TYPE.MOUSE_MOTION, self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## ------------------------------------------------------------------------------
## INPUT HANDLING (The Director)
## ------------------------------------------------------------------------------

## This function is executed by InputHandler for the subscribed intentions.
func execute_intention(intention: InputHandler.Intention) -> void:
	var event: InputEvent = intention.event
	var mouse_pos: Vector2 = intention.position

	# 1. HANDLE CLICKS & RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var id = graph.get_vertex_collision(mouse_pos)

			# If we clicked a vertex (and not holding Ctrl), start dragging
			if id != Globals.NOT_FOUND and not Input.is_key_pressed(KEY_CTRL):
				dragged_vertex_id = id
				is_dragging = true
			else:
				# ONLY spawn if we aren't clicking an existing vertex
				if id == Globals.NOT_FOUND:
					if Input.is_key_pressed(KEY_CTRL):
						_handle_path_connection(mouse_pos)
					else:
						_handle_vertex_placement(mouse_pos)
		else:
			# Mouse released: stop dragging
			is_dragging = false
			dragged_vertex_id = Globals.NOT_FOUND

	# 2. HANDLE MOTION
	if event is InputEventMouseMotion and is_dragging:
		var v = graph.get_vertex(dragged_vertex_id)
		if v:
			v.pos = mouse_pos # Move the brain, the puppet will follow in _process
	
## Handles vertex placement.
## Creates a vertex at posistion.
func _handle_vertex_placement(pos:Vector2) -> void:
	graph.add_vertex(pos, Color.GREEN)

## Handles connecting a few vertices in a row.
## If user clicked on a vertex, it's ID is remembered.
## When 2 different vertices have been clicked, add an edge between them.
func _handle_path_connection(pos: Vector2) -> void:
	var id = graph.get_vertex_collision(pos)

	# --- SMART ADDITION: Clicked empty space ---
	if id == Globals.NOT_FOUND:
		# 1. Create the new vertex
		var new_id = graph._next_vertex_id 
		graph.add_vertex(pos, Color.YELLOW)

		# 2. If we had a previous selection, connect it to the brand new vertex
		if not selection_buffer.is_empty():
			graph.add_edge(selection_buffer.back(), new_id)

		# 3. Add to buffer to continue the path from this new point
		selection_buffer.append(new_id)
		return		

	# Case 2: If the vertex is the last element, uncheck it
	if not selection_buffer.is_empty() and selection_buffer.back() == id:
		selection_buffer.erase(id)
		var u = graph.get_vertex(id)
		if u: u.color = Color.WHITE
		return

	# Case 3: Add new vertex to the path
	selection_buffer.append(id)
	var v = graph.get_vertex(id)

	# Add a feedback: color the path
	if v: v.color = Color.YELLOW 

	# Gives fidback instantly, auto connects automatically
	if selection_buffer.size() >= 2:
		var from_id = selection_buffer[selection_buffer.size() - 2]
		var to_id = selection_buffer.back()
		graph.add_edge(from_id, to_id)
