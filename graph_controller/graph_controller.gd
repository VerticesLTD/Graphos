## Controls the graph: input, selection, and Ctrl-connect session state. (GraphController)
extends Node
class_name GraphController

const VERTEX_ON_TOP = 2
const VERTEX_BELOW = 1

## Allows the controller to control the graph
@export var graph: Graph

## UI overlay that draws/opens context menus
@onready var popup_menu: GraphContextMenuManager = $"../CanvasLayer/PopupMenuLayer"
@onready var math_grid_background: MathGridBackground = $"../MathGridBackground"

## Ctrl-connect session: active endpoint for the *next* edge (not inferred from order tail).
var link_head: int = Globals.NOT_FOUND
## Distinct vertices touched this session (for coloring).
var link_session: Dictionary = {}
## Visit order for undo (may repeat vertex ids when revisiting).
var link_order: Array[int] = []

## The rectangle which bounds the selection
var selection_bounds: Rect2 = Rect2()


## Holds nodes selected by user mass select
var selection_buffer: Array[Vertex] = []:
	set(value):
		selection_buffer = value
		if animation_manager:
			animation_manager.update_current_selection(selection_buffer)
			
		update_selection_bounds()
			
## Animation manager responsible for animations at the controller level
@onready var animation_manager: AnimationManager = $AnimationManager

## A class which holds a player with all the algorithm commands.
@onready var player: AlgorithmPlayer = $AlgorithmPlayer



## A map linking actions to the functions handling them
## <ACTION> : [<PRESS FUNCTION>, <RELEASE FUNCTION>]
var action_map: Dictionary = {
	&"undo" : [func(_event): CommandManager.undo(), null],
	&"redo" : [func(_event): CommandManager.redo(), null],
}

var action_map_algorithm_player: Dictionary = {
	&"ui_right" : [func(_event): player.step_forward(), null],
	&"ui_left" : [func(_event): player.step_backward(), null],
	&"ui_accept" : [func(_event): player.toggle_auto_playing(), null],
}

const HOLD_REPEAT_INITIAL_DELAY := 0.28
const HOLD_REPEAT_INTERVAL := 0.07
var _held_algorithm_action: StringName = &""
var _held_algorithm_timer := 0.0
var _held_history_action: StringName = &""
var _held_history_timer := 0.0
var _last_tool_state: int = -1

## Vars to handle dragging
## Stores { Vertex: Vector2_Initial_Pos } for whatever is being dragged
var drag_snapshot: Dictionary = {}
var is_dragging: bool = false

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# If the app's state changed, we want to reset selection
	Globals.app_state_changed.connect(self.clear_selection_buffer)
	CommandManager.history_changed.connect(prune_selection_to_live_graph)

	## Inject graph into popup manager so it can create commands like DeleteVertexCommand.new(graph, v)
	if popup_menu:
		popup_menu.graph = graph
		popup_menu.controller = self 

		# Making sure the menu starts algorithm execution
		popup_menu.run_algorithm.connect(self.execute_algorithm)
		popup_menu.toggle_grid_requested.connect(_on_toggle_grid_requested)
	else:
		push_warning("GraphController: popup manager not assigned in Inspector.")

	if math_grid_background:
		math_grid_background.set_grid_enabled(false)
	

func _process(delta: float) -> void:
	if Globals.current_state != _last_tool_state:
		if Globals.current_state == Globals.State.PAN and animation_manager:
			animation_manager.clear_all_selection_hovers()
		_last_tool_state = Globals.current_state

	# If we are currently dragging nodes, we do not want to touch
	# the selection buffer.
	if Globals.is_mass_select and not is_dragging:
		_populate_selection_buffer()
	_process_algorithm_key_hold(delta)
	_process_history_key_hold(delta)

## ------------------------------------------------------------------------------
## INPUT HANDLING
## ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Globals.current_state == Globals.State.PAN:
		return

	if event is InputEventKey:
		# Ctrl+Z / Ctrl+Y: first press applies once, then repeats while held.
		if event.is_action_pressed("undo") and not event.echo:
			CommandManager.undo()
			_held_history_action = &"undo"
			_held_history_timer = HOLD_REPEAT_INITIAL_DELAY
			return
		if event.is_action_pressed("redo") and not event.echo:
			CommandManager.redo()
			_held_history_action = &"redo"
			_held_history_timer = HOLD_REPEAT_INITIAL_DELAY
			return
		if event.is_action_released("undo") and _held_history_action == &"undo":
			_held_history_action = &""
			return
		if event.is_action_released("redo") and _held_history_action == &"redo":
			_held_history_action = &""
			return

	# Close text editor if needed
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
		if not player.is_algorithm_running():
			_held_algorithm_action = &""
			return
		if event is InputEventKey:
			# Left/right support hold-to-repeat:
			# first press steps once, then repeats while key is held.
			if event.is_action_pressed("ui_left") and not event.echo:
				player.step_backward()
				_held_algorithm_action = &"ui_left"
				_held_algorithm_timer = HOLD_REPEAT_INITIAL_DELAY
				return
			if event.is_action_pressed("ui_right") and not event.echo:
				player.step_forward()
				_held_algorithm_action = &"ui_right"
				_held_algorithm_timer = HOLD_REPEAT_INITIAL_DELAY
				return
			if event.is_action_released("ui_left") and _held_algorithm_action == &"ui_left":
				_held_algorithm_action = &""
				return
			if event.is_action_released("ui_right") and _held_algorithm_action == &"ui_right":
				_held_algorithm_action = &""
				return
			# Ignore key-repeat events for non-hold actions like ui_accept.
			if event.echo:
				return
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


func _process_algorithm_key_hold(delta: float) -> void:
	if not player or not player.is_algorithm_running():
		_held_algorithm_action = &""
		return
	if _held_algorithm_action == &"":
		return
	if not Input.is_action_pressed(_held_algorithm_action):
		_held_algorithm_action = &""
		return

	_held_algorithm_timer -= delta
	while _held_algorithm_timer <= 0.0:
		if _held_algorithm_action == &"ui_left":
			player.step_backward()
		elif _held_algorithm_action == &"ui_right":
			player.step_forward()
		_held_algorithm_timer += HOLD_REPEAT_INTERVAL

func _process_history_key_hold(delta: float) -> void:
	if _held_history_action == &"":
		return
	if not Input.is_action_pressed(_held_history_action):
		_held_history_action = &""
		return

	_held_history_timer -= delta
	while _held_history_timer <= 0.0:
		if _held_history_action == &"undo":
			CommandManager.undo()
		elif _held_history_action == &"redo":
			CommandManager.redo()
		_held_history_timer += HOLD_REPEAT_INTERVAL

## Starts dragging a node
func start_dragging(id: int = Globals.NOT_FOUND) -> void:
	is_dragging = true
	drag_snapshot.clear()
	
	# Clicked inside the bounding box (id is NOT_FOUND)
	# or clicked a vertex that is already part of the selection.
	var clicked_v = graph.get_vertex(id)
	if id == Globals.NOT_FOUND or selection_buffer.has(clicked_v):
		for v in selection_buffer:
			drag_snapshot[v] = v.pos
		update_selection_bounds()
		return # Group drag initialized

	# Clicked a single vertex that ISN'T selected
	if clicked_v:
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
		var cmd = MoveSelectionCommand.new(drag_snapshot, self)
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

## Clears Ctrl-connect path state and vertex chain colors.
func clear_link_context(_event: InputEvent) -> void:
	for vid in link_session:
		var v = graph.get_vertex(int(vid))
		if v:
			v.color = Globals.VERTEX_COLOR
	link_session.clear()
	link_order.clear()
	link_head = Globals.NOT_FOUND


func sync_link_session_from_order() -> void:
	link_session.clear()
	for vid in link_order:
		link_session[vid] = true

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
	update_selection_bounds()

## Manually sets the selection buffer to a specific set of vertices.
## Useful for PasteCommand.
func select_vertices(vertices_to_select: Array[Vertex]) -> void:
	# Clear current selection
	selection_buffer.clear() 
	
	# Populate the buffer
	for v in vertices_to_select:
		v.z_idx = VERTEX_ON_TOP
		selection_buffer.append(v)
	
	# Update the box
	update_selection_bounds()

		
## Drops selection entries that no longer exist on the graph (e.g. after undo removes a vertex).
func prune_selection_to_live_graph() -> void:
	var kept: Array[Vertex] = []
	for v in selection_buffer:
		if v != null and graph.vertices.has(v.id):
			kept.append(v)
	if kept.size() == selection_buffer.size():
		return
	if kept.is_empty():
		clear_selection_buffer()
		return
	select_vertices(kept)

## Clears selection buffer.
func clear_selection_buffer() -> void:
	# Resetting color
	for v in selection_buffer:
		v.z_idx = VERTEX_BELOW

	selection_buffer.clear()
	animation_manager.update_current_selection(selection_buffer)
	update_selection_bounds()

## Refreshes chain / head colors from link_session + link_head.
func refresh_link_buffer_colors() -> void:
	if link_session.is_empty():
		return
	for vid in link_session:
		_set_vertex_color(int(vid), Globals.VERTEX_COLOR_CHAIN)
	if link_head != Globals.NOT_FOUND:
		_set_vertex_color(link_head, Globals.VERTEX_COLOR_CHAIN_HEAD)
	
	
## Sets a vertex color. id may be untyped because callers can pass null.
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
	if Globals.active_weight_editor:
		if Globals.active_weight_editor.has_meta("inline_weight_editor"):
			Globals.active_weight_editor.release_focus()
		else:
			Globals.active_weight_editor.queue_free()
		Globals.active_weight_editor = null
		
## ------------------------------------------------------------------------------
## ALGORITHM PLAYER
## ------------------------------------------------------------------------------

func execute_algorithm(algorithm: AlgorithmPlayer.ALGORITHMS, start_node: Vertex) -> void:
	var resolved_start: Vertex = _resolve_start_vertex_for_algorithm(algorithm, start_node)
	if _algorithm_requires_start_vertex(algorithm) and resolved_start == null:
		return
	player.start_algorithm(algorithm, resolved_start, selection_buffer, graph)

func _resolve_start_vertex_for_algorithm(algorithm: AlgorithmPlayer.ALGORITHMS, start_node: Vertex) -> Vertex:
	if not _algorithm_requires_start_vertex(algorithm):
		return start_node

	if start_node != null:
		return start_node

	var fallback_start := _pick_smallest_id_vertex(selection_buffer)
	if fallback_start:
		Notify.show_notification(
			"No start vertex selected. Starting from vertex %d." % fallback_start.id
		)
		return fallback_start

	Notify.show_error("Algorithm Error: Please select at least one vertex.")
	return null

func _algorithm_requires_start_vertex(algorithm: AlgorithmPlayer.ALGORITHMS) -> bool:
	match algorithm:
		AlgorithmPlayer.ALGORITHMS.BFS, AlgorithmPlayer.ALGORITHMS.DFS, AlgorithmPlayer.ALGORITHMS.DIJKSTRA, AlgorithmPlayer.ALGORITHMS.PRIM:
			return true
		AlgorithmPlayer.ALGORITHMS.KRUSKAL:
			return false
		_:
			return false

func _pick_smallest_id_vertex(vertices: Array[Vertex]) -> Vertex:
	if vertices.is_empty():
		return null
	var best: Vertex = vertices[0]
	for v in vertices:
		if v and v.id < best.id:
			best = v
	return best

func update_selection_bounds(radius_scale: float = Globals.VERTEX_HOVER_SCALE) -> void:
	if selection_buffer.is_empty():
		selection_bounds = Rect2()
		return
	else:
		# Create and expand rectangle
		var new_bounds = Rect2(selection_buffer[0].pos, Vector2.ZERO)
		for v in selection_buffer:
			new_bounds = new_bounds.expand(v.pos)
		var selected_visual_radius = Globals.VERTEX_RADIUS * radius_scale
		selection_bounds = new_bounds.grow(selected_visual_radius + Globals.SELECTION_BOUNDS_PADDING)

	if has_node("UISelectionBounds"):
		get_node("UISelectionBounds").queue_redraw()

func _on_toggle_grid_requested(enabled: bool) -> void:
	if math_grid_background:
		math_grid_background.set_grid_enabled(enabled)
