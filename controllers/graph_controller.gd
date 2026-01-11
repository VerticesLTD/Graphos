## A class to control the graph, recieves inputs, and changes the graph. extends Node class_name GraphController
extends Node
class_name GraphController

const VERTEX_ON_TOP = 2
const VERTEX_BELOW = 1

## Allows the controller to control the graph
@export var graph: UndirectedGraph

## UI overlay that draws/opens context menus
@export var popup: GraphContextMenuManager

## The selection buffer to link multiple nodes with an edge
var link_buffer: Array[int] = []

## Holds nodes selected by user mass select
var selection_buffer: Array[Vertex] = []:
	set(value):
		selection_buffer = value
		# Keeps animation manager updated with selected vertices
		animation_manager.update_current_selection(selection_buffer)

## Animation manager responsible for animations at the controller level
@onready var animation_manager: AnimationManager = $AnimationManager

## A class which holds a player with all the algorithm commands.
var player: AlgorithmPlayer

## A map linking actions to the functions handling them
## <ACTION> : [<PRESS FUNCTION>, <RELEASE FUNCTION>]
var action_map: Dictionary = {
	&"left_click" : [_handle_left_click, _handle_left_release],
	&"left_click_ctrl" : [null, null],
	&"right_click" : [_handle_right_click, _handle_left_release],
	&"right_click_ctrl" : [null, null],
	&"ctrl" : [null, _clear_link_context],
	&"press_B" : [null, null],
	&"undo" : [func(): CommandManager.undo(), null],
	&"redo" : [func(): CommandManager.redo(), null],
	&"delete" : [_handle_delete_pressed, null],
	&"copy" : [_handle_copy_pressed, null],
	&"paste" : [_handle_paste_pressed, null],
	&"cut" : [_handle_cut_pressed, null]
}

var action_map_algorithm_player: Dictionary = {
	&"ui_right" : [func(_event): player.step_forward(), null],
	&"ui_left" : [func(_event): player.step_backward(), null],
}

## Vars to handle dragging
## Stores { Vertex: Vector2_Initial_Pos } for whatever is being dragged
var drag_snapshot: Dictionary = {}
var is_dragging: bool = false

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# If the app's state changed, we want to reset selection
	Globals.app_state_changed.connect(self._clear_selection_buffer)

	## Inject graph into popup manager so it can create commands like DeleteVertexCommand.new(graph, v)
	if popup:
		popup.graph = graph
		popup.controller = self 
	else:
		push_warning("GraphController: popup manager not assigned in Inspector.")

func _process(_delta: float) -> void:
	# If we are currently draggin nodes, we do not want to touch
	# the selection buffer.
	if Globals.is_mass_select and not is_dragging:
		_populate_selection_buffer()

## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# If the menu closed less than 200ms ago, ignore ALL clicks.
	# This prevents "Accidental Vertices" (Left Click)
	if popup and popup.MainMenu.visible:
			# If it's a mouse click, we consume it so it doesn't create vertices or re-open menus
			if event is InputEventMouseButton and event.pressed:
				get_viewport().set_input_as_handled()
			return		
		
	# Special case we explicitly check for
	if event is InputEventMouseMotion:
		_handle_mouse_movement(event)
		return

	# MacOs ctrl+left_click is right click. Needs to be handled.
	if event.is_action_pressed("right_click_ctrl") and OS.get_name() == "macOS":
		_handle_left_click(event)
		return

	if event.is_action_released("right_click_ctrl") and OS.get_name() == "macOS":
		_handle_left_release(event)
		return
	
	for action: StringName in action_map.keys():
		# Callables from action map
		var pressed_handler = action_map[action].get(0)
		var release_handler = action_map[action].get(1)

		if event.is_action_pressed(action) and pressed_handler:
			pressed_handler.call(event)
			return

		if event.is_action_released(action) and release_handler:
			release_handler.call(event)
			return	
	
	if player:
		for action: StringName in action_map_algorithm_player.keys():
			# Callables from action map
			var pressed_handler = action_map_algorithm_player[action].get(0)
			var release_handler = action_map_algorithm_player[action].get(1)

			if event.is_action_pressed(action) and pressed_handler:
				pressed_handler.call(event)
				return

			if event.is_action_released(action) and release_handler:
				release_handler.call(event)
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
	var id = graph.get_vertex_id_at(_mouse_global_pos)
	if id != Globals.NOT_FOUND:
		# Change cursor to a 'Pointing Hand' when over a node
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_dragging(event: InputEventMouseMotion):
	# We move everything in the snapshot by the mouse delta (relative)
	for v in drag_snapshot.keys():
		v.pos += event.relative
		v.z_idx = VERTEX_ON_TOP
	

## Starts dragging a node
func _start_dragging(id: int) -> void:
	is_dragging = true
	drag_snapshot.clear()
	
	var clicked_v = graph.get_vertex(id)
	if not clicked_v: return

	# If clicking something already in selection, drag the whole group
	if selection_buffer.has(clicked_v):
		for v in selection_buffer:
			drag_snapshot[v] = v.pos
	# Otherwise, just drag the single clicked vertex
	else:
		drag_snapshot[clicked_v] = clicked_v.pos
		

func _stop_dragging() -> void:
	if not is_dragging: return
	
	# Check if anything actually moved compared to the snapshot
	var has_moved = false
	for v in drag_snapshot.keys():
		if v.pos != drag_snapshot[v]:
			has_moved = true
			break
	
	if has_moved:
		# One command to rule them all!
		var cmd = MoveSelectionCommand.new(drag_snapshot)
		CommandManager.push_to_stack(cmd)

	# Visual cleanup
	for v in drag_snapshot.keys():
		v.z_idx = VERTEX_BELOW

	is_dragging = false
	drag_snapshot.clear()
	
	
## ------------------------------------------------------------------------------
## LEFT_CLICKS & LEFT_RELEASES 
## ------------------------------------------------------------------------------

func _handle_left_click(event: InputEventMouseButton):
	var mouse_global_pos = event.global_position

	# Get the vertex in the position of the mouse(or not found)
	var id = graph.get_vertex_id_at(mouse_global_pos)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)

	# 1. CLICKED VERTEX  
	if id != Globals.NOT_FOUND:
		if is_ctrl and Globals.current_state == Globals.State.CREATE:
			_handle_path_connection(mouse_global_pos)
		else:
			_start_dragging(id)
		return
		
	# 2. CLICKED EMPTY SPACE INTERACTION WHILE VERTEX STATE
	if Globals.current_state == Globals.State.CREATE:
		if is_ctrl:
			_handle_path_connection(mouse_global_pos) # Create & Connect

		# We only place a vertex if there are no nodes selected
		elif selection_buffer.is_empty():
			_handle_vertex_placement(mouse_global_pos) # Just create
	
	# Clearing node selection on an empty click
	_clear_selection_buffer()
	
func _handle_left_release(_event: InputEventMouseButton):
	# Always stop dragging when the mouse is let go
	_stop_dragging()

		
## ------------------------------------------------------------------------------
## RIGHT_CLICKS & RIGHT_RELEASES 
## ------------------------------------------------------------------------------
func _handle_right_click(event: InputEventMouseButton):
	var mouse_global_pos = event.global_position

	## 1. Check vertex at mouse
	var v_id = graph.get_vertex_id_at(mouse_global_pos)
	if v_id != Globals.NOT_FOUND:
		var v: Vertex = graph.get_vertex(v_id)
		if v and popup:
			popup.open_for_vertex(v, mouse_global_pos)
		return

	## 2. Check edge at mouse
	var edge = graph.get_edge_at(mouse_global_pos)
	if edge != null:
		if popup:
			popup.open_for_edge(edge, mouse_global_pos)
		return

	## 3. Empty space
	if popup:
		popup.open_for_canvas(mouse_global_pos)
	pass
	
func _handle_right_release(_event: InputEventMouseButton):
	pass
	

## ------------------------------------------------------------------------------
## HELPERS / STATE MANAGEMENT
## ------------------------------------------------------------------------------

## Creates and performs an add vertex command.
func _handle_vertex_placement(pos: Vector2) -> void:
	# Create and execute the command
	CommandManager.execute(AddVertexCommand.new(graph, pos))


## Handles connecting a few vertices in a row.
## If user clicked on a vertex, it's ID is remembered.
## When 2 different vertices have been clicked, add an edge between them.
func _handle_path_connection(pos: Vector2) -> void:
	var id = graph.get_vertex_id_at(pos)
	var last_id = link_buffer.back() if not link_buffer.is_empty() else Globals.NOT_FOUND
	
	# 1. EMPTY SPACE: Create
	if id == Globals.NOT_FOUND:
		var step = PathStepCommand.new(graph, pos, last_id)
		CommandManager.execute(step)
		link_buffer.append(step.v_cmd.vertex.id)

	# 2. LAST VERTEX: Undo
	elif not link_buffer.is_empty() and link_buffer.back() == id:
		var v_to_undo = graph.get_vertex(id)
		if v_to_undo:
			# Find the previous ID in the buffer for the connection
			var prev_id = link_buffer[link_buffer.size() - 2] if link_buffer.size() >= 2 else Globals.NOT_FOUND
			
			# Execute the Macro
			var macro = PathUndoCommand.new(graph, v_to_undo, prev_id)
			CommandManager.execute(macro)
			
			link_buffer.pop_back() # Update buffer

	# 3. EXISTING VERTEX: connect
	else:
		if last_id != Globals.NOT_FOUND and _should_add_connection(last_id, id):
			CommandManager.execute(AddEdgeCommand.new(graph, last_id, id))
		link_buffer.append(id)
	
	_refresh_link_buffer_colors()


## Clears the seletion buffer for linking nodes.
func _clear_link_context(_event: InputEvent) -> void:
	# 1. Clean the visual feedback
	for id in link_buffer:
		var v = graph.get_vertex(id)

		if v: v.color = Globals.VERTEX_COLOR
	
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

## Manually sets the selection buffer to a specific set of vertices.
## Useful for PasteCommand.
func select_vertices(vertices_to_select: Array[Vertex]) -> void:
	# 1. Start fresh
	_clear_selection_buffer()
	
	# 2. Add each vertex to selection (AnimationManager will highlight)
	for v in vertices_to_select:
		v.z_idx = VERTEX_ON_TOP
		selection_buffer.append(v)


## Clears selection buffer.
func _clear_selection_buffer() -> void:
	# Resetting color
	for v in selection_buffer:
		v.color = Globals.VERTEX_COLOR
		v.z_idx = VERTEX_BELOW

	selection_buffer.clear()

func _handle_delete_pressed(_event: InputEvent) -> void:
	if selection_buffer:
		CommandManager.execute(DeleteSelectionCommand.new(graph, selection_buffer))

func _handle_copy_pressed(_event: InputEvent) -> void:
	if selection_buffer:
		# Clean up old clipboard memory
		if Globals.clipboard_graph:
			Globals.clipboard_graph.queue_free()
		
		# Create the snapshot
		Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
		GLogger.debug("Selection copied to clipboard.","CLIPBORAD")

func _handle_paste_pressed(_event: InputEvent) -> void:
	if Globals.clipboard_graph:
		var mouse_pos = graph.get_global_mouse_position()
		
		var paste_cmd = PasteCommand.new(graph, Globals.clipboard_graph, mouse_pos, self)

		GLogger.debug("Selection pasted.","CLIPBORAD")

		CommandManager.execute(paste_cmd)

func _handle_cut_pressed(_event: InputEvent) -> void:
	if selection_buffer:
		# Clean up old clipboard memory
		if Globals.clipboard_graph:
			Globals.clipboard_graph.queue_free()
		
		# Create the snapshot
		Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
		GLogger.debug("Selection copied to clipboard.","CLIPBOARD")
		
		# Delete the selected sub-graph	
		CommandManager.execute(DeleteSelectionCommand.new(graph, selection_buffer))

## ONLY refreshes the link buffer colors. It doesn't touch the Array logic.
func _refresh_link_buffer_colors() -> void:
	if link_buffer.is_empty():
		return

	# 1. Paint everything in the buffer as "Path" nodes
	for id in link_buffer:
		_set_vertex_color(id, Globals.VERTEX_COLOR_CHAIN)

	# 2. Paint the very last one as the "Active Head"
	_set_vertex_color(link_buffer.back(), Globals.VERTEX_COLOR_CHAIN_HEAD)
	
	
## Sets a vertex color. id type isnt mantioned because we can get null.
func _set_vertex_color(id, color: Color) -> void:
	if id == null:
		return
	var v = graph.get_vertex(id)
	if v: v.color = color

## Returns true if position has a vertex.
func is_vertex_collision(pos: Vector2) -> bool:
	return graph.get_vertex_id_at(pos) != Globals.NOT_FOUND

## Checks if you can add a connection between 2 vertices
func _should_add_connection(from_id: int, to_id: int) -> bool:
	return from_id != Globals.NOT_FOUND and \
		   from_id != to_id and \
		   not graph.has_edge(from_id, to_id)

## ------------------------------------------------------------------------------
## ALGORITHM PLAYER
## ------------------------------------------------------------------------------

## This function can now run BFS, DFS, Dijkstra, or any future algorithm.
## @param algo_class: The Script/Class of the algorithm (e.g., BFS)
## @param start_node: The real vertex where we want to begin
func execute_algorithm(algo_class: GDScript, start_node: Vertex) -> void:
	# 1. Create the Imposter Graph (The Sandbox)
	# Pass the selection buffer to run the algo on the sub-graph
	var imposter_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
	
	# 2. Instantiate the specific algorithm generically
	# Every child of GraphAlgorithm uses the same _init(_imposter, _real)
	var algo_instance: GraphAlgorithm = algo_class.new(imposter_graph, graph)
	
	# 3. Find the starting vertex's equivalent in the imposter graph
	var imposter_start_node = imposter_graph.get_vertex(start_node.id)
	
	# 4. RUN the algorithm to generate the timeline
	var timeline = algo_instance.run(imposter_start_node)
	
	# 5. Initialize the playback
	player = AlgorithmPlayer.new(timeline)
	
	# 6. Cleanup the imposter graph
	# The timeline already has the Commands targeting the REAL graph
	imposter_graph.queue_free()
	
	print("Algorithm logic finished. Timeline recorded with %d steps." % timeline.size())

## Recieves the player from the Command
func set_algorithm_player(new_player: AlgorithmPlayer) -> void:
	self.player = new_player
	GLogger.debug("New algorithm player")
	# Trigger first step immidietly
	player.step_forward()
