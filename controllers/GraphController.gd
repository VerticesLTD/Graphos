## A class to control the graph, recieves inputs, and changes the graph.
extends Node
class_name GraphController

## Allows the controller to control the graph
@export var graph: UndirectedGraph

## Vars to handle vertex being dragged.
var dragged_vertex_id: int = Globals.NOT_FOUND
var is_dragging: bool = false

## The selection buffer to select multiple nodes
var selection_buffer: Array[int] = []

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Subscribe to intentions to catch input
	InputHandler.subscribe_to_intention(InputHandler.INTENTION_TYPE.MOUSE_CLICK, self)
	InputHandler.subscribe_to_intention(InputHandler.INTENTION_TYPE.MOUSE_MOTION, self)
	InputHandler.subscribe_to_intention(InputHandler.INTENTION_TYPE.KEYBOARD, self)
	
## Called every frame.
func _process(delta: float) -> void:
	pass

## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

## This function is executed by InputHandler for the subscribed intentions.
func execute_intention(intention: InputHandler.Intention) -> void:
	# Grab the data from the intention 
	var event: InputEvent = intention.event
	var mouse_pos: Vector2 = intention.position

	# 1. MOTION (Dragging)
	# Handled first because its the most frequent one.
	if event is InputEventMouseMotion:
		_handle_mouse_movement(mouse_pos)
		return

	# 2. LEFT_CLICKS & LEFT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_handle_left_click(mouse_pos)
		else:
			_handle_left_release()
			
	# 3. RIGHT_CLICKS & RIGHT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			_handle_right_click(mouse_pos)
		else:
			_handle_right_release()
			
	# 4. RELEASE CTRL
	if event is InputEventKey and event.keycode == KEY_CTRL:
		if not event.is_pressed():
			# If they let go of Ctrl, wipe the selection
			_clear_selection_context()
			return


## ------------------------------------------------------------------------------
## MOUSE MOVEMENTS 
## ------------------------------------------------------------------------------
	
## Handle mouse movement
func _handle_mouse_movement(mouse_pos: Vector2):
	# LANE 1: PASSIVE (Hovering)
	# This runs every time the mouse moves, regardless of dragging.
	_handle_hover(mouse_pos)

	# LANE 2: ACTIVE (Dragging)
	# We only proceed here if a drag is actually in progress.
	if is_dragging:
		_handle_dragging(mouse_pos)
		
		
func _handle_hover(mouse_pos: Vector2):
	pass

func _handle_dragging(mouse_pos: Vector2):
	pass

## Starts dragging a node
func _start_dragging(id: int) -> void:
	dragged_vertex_id = id
	is_dragging = true
	# OPTIONAL add 'v.z_index = 1' here to make the dragged node appear on top

## If mouse release and ctrl released, stop dragging.
func _stop_dragging() -> void:
	is_dragging = false
	dragged_vertex_id = Globals.NOT_FOUND

## ------------------------------------------------------------------------------
## LEFT_CLICKS & LEFT_RELEASES 
## ------------------------------------------------------------------------------
func _handle_left_click(mouse_pos: Vector2):
	# Get the vertex in the position of the mouse(or not found)
	var id = graph.get_vertex_collision(mouse_pos)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)

	# 1. CLICKED VERTEX  
	if id != Globals.NOT_FOUND:
		if is_ctrl:
			_handle_path_connection(mouse_pos)
		else:
			_start_dragging(id)
		return
		
	# 2. CLICKED EMPTY SPACE INTERACTION 
	if is_ctrl:
		_handle_path_connection(mouse_pos) # Create & Connect
	else:
		_handle_vertex_placement(mouse_pos) # Just create
	
func _handle_left_release():
	# Always stop dragging when the mouse is let go
	_stop_dragging()

		

## ------------------------------------------------------------------------------
## RIGHT_CLICKS & RIGHT_RELEASES 
## ------------------------------------------------------------------------------
func _handle_right_click(mouse_pos: Vector2):
	pass
	
func _handle_right_release():
	pass


## ------------------------------------------------------------------------------
## HELPERS / STATE MANAGEMENT
## ------------------------------------------------------------------------------

## Handles vertex placement. Creates a vertex at posistion.
func _handle_vertex_placement(pos:Vector2) -> void:
	graph.add_vertex(pos, Color.WHITE)

## Handles connecting a few vertices in a row.
## If user clicked on a vertex, it's ID is remembered.
## When 2 different vertices have been clicked, add an edge between them.
func _handle_path_connection(pos: Vector2) -> void:
	var id = graph.get_vertex_collision(pos)

	# Clicked empty space 
	if id == Globals.NOT_FOUND:
		# 1. Create the new vertex
		var new_id = graph._next_vertex_id 
		graph.add_vertex(pos, Color.GREEN_YELLOW)

		# 2. If we had a previous selection, connect it to the brand new vertex
		if not selection_buffer.is_empty():
			graph.add_edge(selection_buffer.back(), new_id)

		# 3. Add to buffer to continue the path from this new point
		selection_buffer.append(new_id)
		return		

	# Case 2: If the vertex is the last element, uncheck it, and remove the edge
	if not selection_buffer.is_empty() and selection_buffer.back() == id:
		var u = graph.get_vertex(id)
		# u.remove_edge(selection_buffer.)

		selection_buffer.erase(id)
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


## Clears the seletion buffer of the vertices.
func _clear_selection_context() -> void:
	# 1. Clean the visual feedback
	for id in selection_buffer:
		var v = graph.get_vertex(id)
		if v: v.color = Color.WHITE
	
	# 2. Empty the logic container
	selection_buffer.clear()
