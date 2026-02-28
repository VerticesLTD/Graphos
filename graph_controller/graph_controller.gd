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

# TODO: Breakdown the player into a component after the visualization is integrated.
## A class which holds a player with all the algorithm commands.
var player: AlgorithmPlayer


## A map linking actions to the functions handling them
## <ACTION> : [<PRESS FUNCTION>, <RELEASE FUNCTION>]
var action_map: Dictionary = {
	&"press_B" : [null, null],
	&"undo" : [func(_event): CommandManager.undo(), null],
	&"redo" : [func(_event): CommandManager.redo(), null],
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
	Globals.app_state_changed.connect(self.clear_selection_buffer)

	## Inject graph into popup manager so it can create commands like DeleteVertexCommand.new(graph, v)
	if popup:
		popup.graph = graph
		popup.controller = self 
	else:
		push_warning("GraphController: popup manager not assigned in Inspector.")

func _process(_delta: float) -> void:
	# If we are currently dragging nodes, we do not want to touch
	# the selection buffer.
	if Globals.is_mass_select and not is_dragging:
		_populate_selection_buffer()

## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_active_editor()
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

## Starts dragging a node
func start_dragging(id: int) -> void:
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
		
func stop_dragging() -> void:
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
## HELPERS / STATE MANAGEMENT
## ------------------------------------------------------------------------------

## Creates and performs an add vertex command.
func handle_vertex_placement(pos: Vector2) -> void:
	if graph.get_edge_at(pos) != null:
		return
	# Create and execute the command
	CommandManager.execute(AddVertexCommand.new(graph, pos))

## Clears the seletion buffer for linking nodes.
func clear_link_context(_event: InputEvent) -> void:
	# 1. Clean the visual feedback
	for id in link_buffer:
		var v = graph.get_vertex(id)

		if v: v.color = Globals.VERTEX_COLOR
	
	# 2. Empty the logic container
	link_buffer.clear()

## Looks for nodes inside Globals.selection_rectangle and adds them
## to buffer.
## This function preserves the order of selection, which is important for animations.
func _populate_selection_buffer() -> void:
	# OPTIMIZE: Lookups can be O(1) with dicts
	var new_selection: Array[Vertex] = []

	# Check what is selected
	var rect = Rect2(Globals.selection_rectangle)
	for v: Vertex in graph.vertices.values():
		if rect.has_point(v.pos):
			# Setting drawing on top
			v.z_idx = VERTEX_ON_TOP

			new_selection.append(v)
	
	# Check what needs to be removed from the previous selection state and update
	# Iterating BACKWARDS to preserve order
	for i in range(selection_buffer.size() -1, -1, -1):
		var v = selection_buffer[i]
		if v not in new_selection:
			selection_buffer.remove_at(i)

	for v in new_selection:
		if v not in selection_buffer:
			selection_buffer.append(v)

	animation_manager.update_current_selection(selection_buffer)

## Manually sets the selection buffer to a specific set of vertices.
## Useful for PasteCommand.
func select_vertices(vertices_to_select: Array[Vertex]) -> void:
	# 1. Start fresh
	clear_selection_buffer()
	
	# 2. Add each vertex to selection (AnimationManager will highlight)
	for v in vertices_to_select:
		v.z_idx = VERTEX_ON_TOP
		selection_buffer.append(v)
	
	animation_manager.update_current_selection(selection_buffer)
	
## Clears selection buffer.
func clear_selection_buffer() -> void:
	# Resetting color
	for v in selection_buffer:
		v.color = Globals.VERTEX_COLOR
		v.z_idx = VERTEX_BELOW

	selection_buffer.clear()
	animation_manager.update_current_selection(selection_buffer)

## ONLY refreshes the link buffer colors. It doesn't touch the Array logic.
func refresh_link_buffer_colors() -> void:
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
func should_add_connection(from_id: int, to_id: int) -> bool:
	return from_id != Globals.NOT_FOUND and \
		   from_id != to_id and \
		   not graph.has_edge(from_id, to_id)

## Close the weight editor
func close_active_editor() -> void:
	if active_weight_editor:
		active_weight_editor.queue_free()
		active_weight_editor = null
		
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
