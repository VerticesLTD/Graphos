extends Node

var controller: GraphController
var _last_mouse_world_pos: Vector2 = Vector2.ZERO
var _has_last_mouse_world_pos := false
var _bounds_scale_tween: Tween

var action_map: Dictionary = {
	&"left_click" : [_handle_left_click, _handle_left_release],
	## Must use the same handlers: when Ctrl is held, Godot matches `left_click_ctrl`, not `left_click`.
	&"left_click_ctrl" : [_handle_left_click, _handle_left_release],
	&"right_click" : [_handle_right_click, _handle_left_release],
	&"right_click_ctrl" : [null, null],
	&"ctrl" : [null, func(_event): controller.clear_link_context(_event)],
}

func _ready() -> void:
	var par_node = get_parent()
	if par_node is not GraphController:
		push_error("Mouse actions node must be a child of the graph controller!")
		queue_free()
	
	controller = par_node

func _unhandled_input(event: InputEvent) -> void:
	if Globals.current_state == Globals.State.PAN:
		# In pan mode, keep right-click context menu working.
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_handle_right_click(event)
				return
			if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
				_handle_right_release(event)
				return
			# Disable left graph interactions while panning.
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				get_viewport().set_input_as_handled()
		return

	# End connect-chain when any Ctrl/Meta key is released. The Input Map action "ctrl"
	# often binds only one physical key, so the other Ctrl side never ran clear_link_context.
	if event is InputEventKey and not event.pressed:
		var pk: int = event.physical_keycode
		# KEY_CTRL + typical Right-Control physical code (not always == KEY_CTRL across backends).
		const _PHYS_CTRL_R := 4194328
		if pk == KEY_CTRL or pk == KEY_META or pk == _PHYS_CTRL_R:
			if not controller.link_buffer.is_empty():
				controller.clear_link_context(event)

	# If the menu closed less than 200ms ago, ignore ALL clicks.
	# This prevents "Accidental Vertices" (Left Click)
	if controller.popup_menu and controller.popup_menu.MainMenu.visible:
			# Still handle right-release cleanup while menu is open.
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
				_handle_right_release(event)
				return
			# If it's a mouse click, we consume it so it doesn't create vertices or re-open menus
			if event is InputEventMouseButton and event.pressed:
				get_viewport().set_input_as_handled()
			return		

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

func _handle_left_click(event: InputEventMouseButton):
	var graph = controller.graph
	var selection_buffer = controller.selection_buffer

	var mouse_global_pos = graph.get_global_mouse_position()
	_last_mouse_world_pos = mouse_global_pos
	_has_last_mouse_world_pos = true

	# Get the vertex in the position of the mouse(or not found)
	var id = graph.get_vertex_id_at(mouse_global_pos)
	# Prefer modifiers on this event (matches `left_click_ctrl`); also support Meta (Cmd on macOS).
	var is_ctrl: bool = event.ctrl_pressed or event.meta_pressed
	if not is_ctrl:
		is_ctrl = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

	# Normal (non-modifier) clicks are not part of the Ctrl path tool — drop stale chain state.
	if not is_ctrl and not controller.link_buffer.is_empty():
		controller.clear_link_context(event)

	# Check if we select something now
	if selection_buffer.size() > 1:
		if controller.selection_bounds.has_point(mouse_global_pos):
			controller.start_dragging()
			return 
			
			
	# Clicked Vertex (not inside the rectangle)  
	if id != Globals.NOT_FOUND:
		var clicked_v: Vertex = graph.get_vertex(id)
		if is_ctrl and Globals.current_state == Globals.State.CREATE:
			_handle_path_connection(mouse_global_pos)
		else:
			if clicked_v:
				controller.select_vertices([clicked_v])
			controller.start_dragging(id)
		return
		
	# 2. CLICKED EMPTY SPACE INTERACTION WHILE VERTEX STATE
	if Globals.current_state == Globals.State.CREATE:
		if graph.vertices.size() >= Globals.MAX_VERTICES:
			Notify.show_error("Vertex limit reached (Max: %d). Try deleting some?" % Globals.MAX_VERTICES)
			return
			
		if is_ctrl:
			_handle_path_connection(mouse_global_pos) # Create & Connect

		# We only place a vertex if there are no nodes selected
		elif selection_buffer.is_empty():
			controller.handle_vertex_placement(mouse_global_pos) # Just create
	
	# Clearing node selection on an empty click
	controller.clear_selection_buffer()
	
func _handle_left_release(event: InputEventMouseButton):
	# Only clear the connect-chain on mouse-up if the modifier is actually released *on this event*.
	# Input.is_key_pressed(KEY_CTRL) can read false for a frame on mouse-up while Ctrl is still held,
	# which cleared link_buffer between chained Ctrl+clicks (edge needed two attempts to appear).
	var mod_still_held := false
	if event is InputEventMouseButton:
		mod_still_held = event.ctrl_pressed or event.meta_pressed
	if not mod_still_held:
		mod_still_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if not mod_still_held and not controller.link_buffer.is_empty():
		controller.clear_link_context(event)
	_cleanup_after_release()

func _handle_right_release(_event: InputEventMouseButton):
	_cleanup_after_release()

func _cleanup_after_release() -> void:
	# Stop dragging
	controller.stop_dragging()
	_has_last_mouse_world_pos = false

	# Stop selection hover visuals to reduce screen clutter.
	if controller.animation_manager:
		controller.animation_manager.clear_all_selection_hovers()

	# Shrink bounds in sync with vertex shrink animation.
	if not controller.selection_buffer.is_empty():
		if _bounds_scale_tween:
			_bounds_scale_tween.kill()
		_bounds_scale_tween = create_tween()
		_bounds_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_bounds_scale_tween.tween_method(
			func(scale: float):
				if is_instance_valid(controller):
					controller.update_selection_bounds(scale),
			Globals.VERTEX_HOVER_SCALE,
			1.0,
			Globals.VERTEX_TWEEN_TIME
		)
	else:
		controller.update_selection_bounds(1.0)


## Handles connecting a few vertices in a row.
## If user clicked on a vertex, it's ID is remembered.
## When 2 different vertices have been clicked, add an edge between them.
func _handle_path_connection(pos: Vector2) -> void:
	var graph = controller.graph
	var link_buffer = controller.link_buffer

	var id = graph.get_vertex_id_at(pos)
	var last_id = link_buffer.back() if not link_buffer.is_empty() else Globals.NOT_FOUND
	
	# 1. EMPTY SPACE: Create
	if id == Globals.NOT_FOUND:
		var step = PathStepCommand.new(graph, pos, last_id)
		CommandManager.execute(step)
		link_buffer.append(step.v_cmd.vertex.id)

	# 2. CLICKED SAME VERTEX AS CHAIN HEAD
	elif not link_buffer.is_empty() and link_buffer.back() == id:
		# With a single vertex in the chain, repeat-click means "reset" — not undo (avoids blocking
		# a fresh two-vertex connect after a failed clear_link_context).
		if link_buffer.size() < 2:
			controller.clear_link_context(null)
			return
		var v_to_undo = graph.get_vertex(id)
		if v_to_undo:
			var prev_id = link_buffer[link_buffer.size() - 2]
			var macro = PathUndoCommand.new(graph, v_to_undo, prev_id)
			CommandManager.execute(macro)
			link_buffer.pop_back()

	# 3. EXISTING VERTEX: connect
	else:
		if last_id != Globals.NOT_FOUND and controller.should_add_connection(last_id, id):
			CommandManager.execute(AddEdgeCommand.new(graph, last_id, id))
		link_buffer.append(id)
	
	controller.refresh_link_buffer_colors()

func _handle_right_click(event: InputEventMouseButton):
	var graph = controller.graph
	var popup_menu = controller.popup_menu
	var mouse_global_pos = graph.get_global_mouse_position()
	var mouse_screen_pos = event.position

	var selection_count := controller.selection_buffer.size()
	var has_multi_selection := selection_count > 1
	var inside_selection := has_multi_selection and controller.selection_bounds.has_point(mouse_global_pos)

	## 1. Check vertex at mouse
	var v_id = graph.get_vertex_id_at(mouse_global_pos)
	if v_id != Globals.NOT_FOUND:
		var v: Vertex = graph.get_vertex(v_id)
		if v and popup_menu:
			if has_multi_selection and controller.selection_buffer.has(v):
				popup_menu.open_for_selection(v, mouse_global_pos, mouse_screen_pos)
			else:
				controller.select_vertices([v])
				popup_menu.open_for_vertex(v, mouse_global_pos, mouse_screen_pos)
		return

	## 2. Multi-selection empty-space context
	if popup_menu and inside_selection:
		popup_menu.open_for_selection(null, mouse_global_pos, mouse_screen_pos)
		return

	## 3. Check edge at mouse
	var edge = graph.get_edge_at(mouse_global_pos)
	if edge != null:
		if popup_menu:
			popup_menu.open_for_edge(edge, mouse_global_pos, mouse_screen_pos)
		return

	## 4. Empty space
	if popup_menu:
		popup_menu.open_for_canvas(mouse_global_pos, mouse_screen_pos)
	pass
	
## Handle mouse movement
func _handle_mouse_movement(_event: InputEventMouseMotion):
	var mouse_world_pos := controller.graph.get_global_mouse_position()

	# LANE 1: PASSIVE (Hovering)
	# This runs every time the mouse moves, regardless of dragging.
	_handle_hover(mouse_world_pos)

	# LANE 2: ACTIVE (Dragging)
	# We only proceed here if a drag is actually in progress.
	if controller.is_dragging and _has_last_mouse_world_pos:
		_handle_dragging(mouse_world_pos - _last_mouse_world_pos)

	_last_mouse_world_pos = mouse_world_pos
	_has_last_mouse_world_pos = true

func _handle_dragging(world_delta: Vector2):
	# Move by world-space delta so dragging remains correct with camera zoom/pan.
	for v in controller.drag_snapshot.keys():
		v.pos += world_delta
		v.z_idx = controller.VERTEX_ON_TOP
	
	controller.update_selection_bounds()

func _handle_hover(_mouse_global_pos: Vector2):
	var is_over_vertex = controller.graph.get_vertex_id_at(_mouse_global_pos) != Globals.NOT_FOUND
	var is_over_selection = not controller.selection_buffer.is_empty() and \
							controller.selection_bounds.has_point(_mouse_global_pos)
	
	if is_over_vertex or is_over_selection:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_MOVE)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
