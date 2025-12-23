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


## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

## This function is executed by InputHandler for the subscribed intentions.
func execute_intention(intention: InputHandler.Intention) -> void:
	# Grab the data from the intention 
	var event: InputEvent = intention.event
	var mouse_global_pos: Vector2 = intention.mouse_global_pos

	# 1. MOTION (Dragging)
	# Handled first because its the most frequent one.
	if event is InputEventMouseMotion:
		_handle_mouse_movement(mouse_global_pos)
		return

	# 2. LEFT_CLICKS & LEFT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_handle_left_click(mouse_global_pos)
		else:
			_handle_left_release()
			
	# 3. RIGHT_CLICKS & RIGHT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			_handle_right_click(mouse_global_pos)
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
func _handle_mouse_movement(mouse_global_pos: Vector2):
	# LANE 1: PASSIVE (Hovering)
	# This runs every time the mouse moves, regardless of dragging.
	_handle_hover(mouse_global_pos)

	# LANE 2: ACTIVE (Dragging)
	# We only proceed here if a drag is actually in progress.
	if is_dragging:
		_handle_dragging(mouse_global_pos)
		
		
func _handle_hover(_mouse_global_pos: Vector2):
	# Idea: make the vertex glow
	pass

func _handle_dragging(mouse_global_pos: Vector2):
	# 1. Get the actual vertex using the ID
	var v = graph.get_vertex(dragged_vertex_id)
	
	# 2. Update the 'pos' property. 
	# THE MAGIC: Because we used a 'set(value)' in the Vertex class, 
	# this will automatically tell the Puppet to move!
	if v:
		v.pos = mouse_global_pos
	

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
func _handle_left_click(mouse_global_pos: Vector2):
	# Get the vertex in the position of the mouse(or not found)
	var id = graph.get_vertex_collision(mouse_global_pos)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)

	# 1. CLICKED VERTEX  
	if id != Globals.NOT_FOUND:
		if is_ctrl:
			_handle_path_connection(mouse_global_pos)
		else:
			_start_dragging(id)
		return
		
	# 2. CLICKED EMPTY SPACE INTERACTION 
	if is_ctrl:
		_handle_path_connection(mouse_global_pos) # Create & Connect
	else:
		_handle_vertex_placement(mouse_global_pos) # Just create
	
func _handle_left_release():
	# Always stop dragging when the mouse is let go
	_stop_dragging()

		

## ------------------------------------------------------------------------------
## RIGHT_CLICKS & RIGHT_RELEASES 
## ------------------------------------------------------------------------------
func _handle_right_click(_mouse_global_pos: Vector2):
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

	# 1. EMPTY SPACE (Creation)
	if id == Globals.NOT_FOUND:
		_process_path_creation(pos)
		return

	# 2. LAST VERTEX (Undo)
	if not selection_buffer.is_empty() and selection_buffer.back() == id:
		_process_path_undo(id)
		return

	# 3. EXISTING VERTEX (Connection)
	_process_path_extension(id)

## Create a vertex where the mouse is, and set it to the head.
func _process_path_creation(pos: Vector2) -> void:
	# Update the head's color
	_set_vertex_color(selection_buffer.back(), Color.GREEN_YELLOW)

	# Create new vertex as the new head
	var new_id = graph.add_vertex(pos, Color.YELLOW)

	# Connect if possible
	if not selection_buffer.is_empty():
		graph.add_edge(selection_buffer.back(), new_id)

	selection_buffer.append(new_id)

## Undo the last operation, remove the previous edge and change the head.
func _process_path_undo(id: int) -> void:
	var victim = graph.get_vertex(id)
	
	# Disconnect from previous
	if selection_buffer.size() >= 2:
		var prev_id = selection_buffer[selection_buffer.size() - 2]
		graph.delete_edge(prev_id, id)
			
	# Remove teh vertex from the selection_buffer
	selection_buffer.pop_back()

	_set_vertex_color(selection_buffer.back(), Color.YELLOW)

	# Delete up or reset the undone vertex.
	if victim and victim.degree == 0:
		graph.delete_vertex(id)
	else:
		if victim: victim.color = Color.WHITE
		
## Chose an existing vertex, connect.
func _process_path_extension(id: int) -> void:
	_set_vertex_color(selection_buffer.back(), Color.GREEN_YELLOW)

	# Connect
	if not selection_buffer.is_empty():
		graph.add_edge(selection_buffer.back(), id)

	# Update new head
	_set_vertex_color(id, Color.YELLOW)
	selection_buffer.append(id)

## Clears the seletion buffer of the vertices.
func _clear_selection_context() -> void:
	# 1. Clean the visual feedback
	for id in selection_buffer:
		var v = graph.get_vertex(id)
		if v: v.color = Color.WHITE
	
	# 2. Empty the logic container
	selection_buffer.clear()

## Sets a vertex color. id type isnt mantioned because we can get null.
func _set_vertex_color(id, color: Color) -> void:
	if id == null:
		return
	var v = graph.get_vertex(id)
	if v: v.color = color
