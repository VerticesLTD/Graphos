## A class to control the graph, recieves inputs, and changes the graph. extends Node class_name GraphController
extends Node
class_name GraphController

const VERTEX_ON_TOP = 2
const VERTEX_BELOW = 1

## Allows the controller to control the graph
@export var graph: UndirectedGraph

## Vars to handle vertex being dragged.
var dragged_vertex_id: int = Globals.NOT_FOUND
var is_dragging: bool = false

## The selection buffer to link multiple nodes with an edge
var link_buffer: Array[int] = []

## Holds nodes selected by user mass select
var selection_buffer: Array[Vertex] = []


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	# If we are currently draggin nodes, we do not want to touch
	# the selection buffer.
	if Globals.is_mass_select and not is_dragging:
		_populate_selection_buffer()

## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# 1. MOTION (Dragging)
	# Handled first because its the most frequent one.
	if event is InputEventMouseMotion:
		_handle_mouse_movement(event)
		return

	# 2. LEFT_CLICKS & LEFT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_handle_left_click(event.global_position)
		else:
			_handle_left_release()
			
	# 3. RIGHT_CLICKS & RIGHT_RELEASES
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			_handle_right_click(event.global_position)
		else:
			_handle_right_release()
			
	# 4. RELEASE CTRL
	if event is InputEventKey and event.keycode == KEY_CTRL:
		if not event.is_pressed():
			# If they let go of Ctrl, wipe the selection
			_clear_link_context()
			return


## ------------------------------------------------------------------------------
## MOUSE MOVEMENTS 
## ------------------------------------------------------------------------------
	
## Handle mouse movement
func _handle_mouse_movement(event: InputEventMouseMotion):
	# LANE 1: PASSIVE (Hovering)
	# This runs every time the mouse moves, regardless of dragging.
	_handle_hover(event.global_position)

	# LANE 2: ACTIVE (Dragging)
	# We only proceed here if a drag is actually in progress.
	if is_dragging:
		_handle_dragging(event)
		
		
func _handle_hover(_mouse_global_pos: Vector2):
	# Idea: make the vertex glow
	pass

func _handle_dragging(event: InputEventMouseMotion):
	# Dragging single node:
	if selection_buffer.is_empty():
		# 1. Get the actual vertex using the ID
		var v = graph.get_vertex(dragged_vertex_id)
		
		
		# 2. Update the 'pos' property. 
		# THE MAGIC: Because we used a 'set(value)' in the Vertex class, 
		# this will automatically tell the Puppet to move!
		if v:
			v.pos = event.global_position
			v.z_idx = VERTEX_ON_TOP
			
	# Move multiple nodes by mose delta
	else:
		for v in selection_buffer:
			v.pos += event.relative
	

## Starts dragging a node
func _start_dragging(id: int) -> void:
	dragged_vertex_id = id
	is_dragging = true

## If mouse release and ctrl released, stop dragging.
func _stop_dragging() -> void:
	is_dragging = false
	if dragged_vertex_id != Globals.NOT_FOUND:
		graph.get_vertex(dragged_vertex_id).z_idx = VERTEX_BELOW
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
		if is_ctrl and Globals.current_state == Globals.State.CREATE:
			_handle_path_connection(mouse_global_pos)
		else:
			_start_dragging(id)
		return
		
	if  Globals.current_state == Globals.State.CREATE:
		# 2. CLICKED EMPTY SPACE INTERACTION WHILE VERTEX STATE
		if is_ctrl:
			_handle_path_connection(mouse_global_pos) # Create & Connect

		# We only place a vertex if there are no nodes selected
		elif selection_buffer.is_empty():
			_handle_vertex_placement(mouse_global_pos) # Just create
	
	# Clearing node selection on an empty click
	_clear_selection_buffer()
	
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
	if not link_buffer.is_empty() and link_buffer.back() == id:
		_process_path_undo(id)
		return

	# 3. EXISTING VERTEX (Connection)
	_process_path_extension(id)

## Create a vertex where the mouse is, and set it to the head.
func _process_path_creation(pos: Vector2) -> void:
	# Create new vertex as the new head
	var new_id = graph.add_vertex(pos, Color.YELLOW)
	
	# Connect if possible
	if not link_buffer.is_empty():
		graph.add_edge(link_buffer.back(), new_id)

	link_buffer.append(new_id)

	_refresh_link_buffer_colors()


## Undo the last operation, remove the previous edge and change the head.
func _process_path_undo(id: int) -> void:
	var victim = graph.get_vertex(id)
	
	# Disconnect from previous
	if link_buffer.size() >= 2:
		var prev_id = link_buffer[link_buffer.size() - 2]
		graph.delete_edge(prev_id, id)
			
	# Remove the vertex from the link_buffer
	link_buffer.pop_back()

	_refresh_link_buffer_colors()

	# Delete up or reset the undone vertex.
	if victim and victim.degree == 0:
		graph.delete_vertex(id)
	else:
		if victim: victim.color = Color.WHITE
		
## Chose an existing vertex, connect.
func _process_path_extension(id: int) -> void:
	# Connect
	if not link_buffer.is_empty():
		graph.add_edge(link_buffer.back(), id)

	# Add the clicked vertex as an head
	link_buffer.append(id)

	_refresh_link_buffer_colors()

## Clears the seletion buffer for linking nodes.
func _clear_link_context() -> void:
	# 1. Clean the visual feedback
	for id in link_buffer:
		var v = graph.get_vertex(id)
		if v: v.color = Color.WHITE
	
	# 2. Empty the logic container
	link_buffer.clear()

# TODO: Highlighting in the populate/clear functions below could
# be optimized.

## Looks for nodes inside Globals.selection_rectangle and adds them
## to buffer.
func _populate_selection_buffer() -> void:
	# Clean slate - If selection updated and no longer includes 
	# some nodes.
	_clear_selection_buffer()

	var rect = Rect2(Globals.selection_rectangle)
	for v: Vertex in graph.vertices.values():
		if rect.has_point(v.pos):
			# Setting highlight color
			v.color = Color.PURPLE

			# Setting drawing on top
			v.z_idx = VERTEX_ON_TOP

			selection_buffer.append(v)

## Clears selection buffer.
func _clear_selection_buffer() -> void:
	# Resetting color
	for v in selection_buffer:
		v.color = Color.WHITE
		v.z_idx = VERTEX_BELOW

	selection_buffer.clear()


## ONLY refreshes the link buffer colors. It doesn't touch the Array logic.
func _refresh_link_buffer_colors() -> void:
	if link_buffer.is_empty():
		return

	# 1. Paint everything in the buffer as "Path" nodes
	for id in link_buffer:
		_set_vertex_color(id, Color.GREEN_YELLOW)

	# 2. Paint the very last one as the "Active Head"
	_set_vertex_color(link_buffer.back(), Color.YELLOW)
	
	
## Sets a vertex color. id type isnt mantioned because we can get null.
func _set_vertex_color(id, color: Color) -> void:
	if id == null:
		return
	var v = graph.get_vertex(id)
	if v: v.color = color

## Returns true if position has a vertex.
func is_vertex_collision(pos: Vector2) -> bool:
	return graph.get_vertex_collision(pos) != Globals.NOT_FOUND
