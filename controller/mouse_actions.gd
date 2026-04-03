extends Node

# Corners scale both axes; edges scale one axis only.
enum ResizeHandle {
	NONE,
	TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT,  # diagonal
	TOP, BOTTOM, LEFT, RIGHT,                         # single-axis
}

# ----------------------------------------------------------------------------
# State
# ----------------------------------------------------------------------------

var controller: GraphController
var _ghost_preview: GhostEdgePreview
var _last_mouse_world_pos: Vector2 = Vector2.ZERO
var _has_last_mouse_world_pos := false
var _bounds_scale_tween: Tween

# Resize session — only meaningful while _is_resizing is true.
var _is_resizing := false
var _resize_handle: ResizeHandle = ResizeHandle.NONE
var _resize_initial_bounds: Rect2  # bounds captured at drag start
var _resize_center: Vector2        # pivot point — center of the initial bounds
var _resize_snapshot: Dictionary   # { Vertex -> Vector2 } positions at drag start

# ----------------------------------------------------------------------------
# Input routing
# ----------------------------------------------------------------------------

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
	if controller.graph:
		_ghost_preview = controller.graph.get_node_or_null("GhostEdgePreview") as GhostEdgePreview

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

	# Release Ctrl/Meta ends the connect session (backup: Input Map "ctrl" may only bind one physical key).
	if event is InputEventKey and not event.pressed:
		var pk: int = event.physical_keycode
		# KEY_CTRL + typical Right-Control physical code (not always == KEY_CTRL across backends).
		const _PHYS_CTRL_R := 4194328
		if pk == KEY_CTRL or pk == KEY_META or pk == _PHYS_CTRL_R:
			if not controller.link_session.is_empty():
				controller.clear_link_context(event)
			_hide_ghost_edge_preview()

	# If the menu closed less than 200ms ago, ignore ALL clicks.
	# This prevents "Accidental Vertices" (Left Click)
	if controller.popup_menu and controller.popup_menu.MainMenu.visible:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_handle_right_release(event)
			return
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_handle_mouse_movement(event)
		return
	# MacOs ctrl+left_click is right click. Needs to be handled.
	if event.is_action_pressed("right_click_ctrl") and OS.get_name() == "macOS":
		_handle_left_click(event)
		_sync_ghost_edge_preview()
		return

	if event.is_action_released("right_click_ctrl") and OS.get_name() == "macOS":
		_handle_left_release(event)
		_sync_ghost_edge_preview()
		return

	for action: StringName in action_map.keys():
		# Callables from action map
		var pressed_handler = action_map[action].get(0)
		var release_handler = action_map[action].get(1)

		if event.is_action_pressed(action) and pressed_handler:
			pressed_handler.call(event)
			if action == &"left_click" or action == &"left_click_ctrl":
				_sync_ghost_edge_preview()
			return

		if event.is_action_released(action) and release_handler:
			release_handler.call(event)
			if action == &"left_click" or action == &"left_click_ctrl" or action == &"right_click":
				_sync_ghost_edge_preview()
			return


# ----------------------------------------------------------------------------
# Ghost edge preview
# ----------------------------------------------------------------------------

func _sync_ghost_edge_preview() -> void:
	if _ghost_preview == null or controller == null or controller.graph == null:
		return
	if controller.is_dragging:
		_ghost_preview.hide_preview()
		return
	_ghost_preview.sync_preview(controller.graph, controller, controller.graph.get_global_mouse_position())


func _hide_ghost_edge_preview() -> void:
	if _ghost_preview:
		_ghost_preview.hide_preview()


func _handle_left_click(event: InputEventMouseButton):
	var graph = controller.graph
	var selection_buffer = controller.selection_buffer

	var mouse_global_pos = graph.get_global_mouse_position()
	_last_mouse_world_pos = mouse_global_pos
	_has_last_mouse_world_pos = true

	var id = graph.get_vertex_id_at(mouse_global_pos)
	# Combine Input + event: modifier on the mouse event can lag or be missing on some OS/backends.
	var is_ctrl: bool = (
		Input.is_key_pressed(KEY_CTRL)
		or Input.is_key_pressed(KEY_META)
		or event.ctrl_pressed
		or event.meta_pressed
	)

	# Resize handles live on the selection boundary — check them first so they
	# win over any vertex or drag-bounds hit beneath them.
	# Consuming the event prevents GlobalUI (which sees _unhandled_input before
	# us) from also spawning a marquee rect on the same click.
	if not is_ctrl:
		var handle := _get_handle_at(mouse_global_pos)
		if handle != ResizeHandle.NONE:
			_start_resize(handle)
			get_viewport().set_input_as_handled()
			return

	# Multi-drag: only when not using Ctrl+connect (otherwise we never reach _handle_path_connection).
	if selection_buffer.size() > 1:
		if controller.selection_bounds.has_point(mouse_global_pos):
			if not (is_ctrl and Globals.current_state == Globals.State.CREATE):
				controller.start_dragging()
				return

	# Clicked Vertex (not inside the rectangle)  
	if id != Globals.NOT_FOUND:
		var clicked_v: Vertex = graph.get_vertex(id)
		if is_ctrl and Globals.current_state == Globals.State.CREATE:
			_handle_path_connection(mouse_global_pos)
		else:
			# Leaving connect-by-Ctrl mode: normal select/drag — drop path state here only (not on every click).
			if not controller.link_session.is_empty():
				controller.clear_link_context(event)
			if clicked_v:
				controller.select_vertices([clicked_v])
			controller.start_dragging(id)
		return
		
	# 2. CLICKED EMPTY SPACE INTERACTION WHILE VERTEX STATE
	if Globals.current_state == Globals.State.CREATE:
		if is_ctrl:
			_handle_path_connection(mouse_global_pos) # Create & Connect

		# We only place a vertex if there are no nodes selected
		elif selection_buffer.is_empty():
			controller.handle_vertex_placement(mouse_global_pos) # Just create
	
	# Empty click without Ctrl ends the connect chain; Ctrl+empty is handled above.
	if not is_ctrl and not controller.link_session.is_empty():
		controller.clear_link_context(event)
	# Clearing node selection on an empty click
	controller.clear_selection_buffer()
	
func _handle_left_release(_event: InputEventMouseButton):
	# Do not clear the Ctrl-connect chain here — was flaky between clicks.
	# Path ends on Ctrl/Meta key release (_unhandled_input) or on non-ctrl click (above).
	_cleanup_after_release()

func _handle_right_release(_event: InputEventMouseButton):
	_cleanup_after_release()

func _cleanup_after_release() -> void:
	# Always stop resize before stop_dragging — both may push to the undo stack
	# and we only ever want one entry per user gesture.
	if _is_resizing:
		_stop_resize()

	controller.stop_dragging()
	_has_last_mouse_world_pos = false

	# Drop the hover-scale animations that were running while the button was held.
	if controller.animation_manager:
		controller.animation_manager.clear_all_selection_hovers()

	# Animate the bounding box padding back to rest size (hover scale → 1.0).
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


## Ctrl+click connect: next edge is always (link_head -> clicked vertex). Session/head live on GraphController.
func _handle_path_connection(pos: Vector2) -> void:
	var graph = controller.graph
	var id := graph.get_vertex_id_at(pos)
	var head: int = controller.link_head

	if id == Globals.NOT_FOUND:
		var step := PathStepCommand.new(graph, pos, head)
		CommandManager.execute(step)
		var new_id: int = step.v_cmd.vertex.id
		controller.link_order.append(new_id)
		controller.sync_link_session_from_order()
		controller.link_head = new_id
		controller.refresh_link_buffer_colors()
		return

	if head != Globals.NOT_FOUND and id == head:
		if controller.link_order.size() < 2:
			controller.clear_link_context(null)
			return
		var v_to_undo := graph.get_vertex(id)
		if v_to_undo:
			var prev_id: int = controller.link_order[controller.link_order.size() - 2]
			CommandManager.execute(PathUndoCommand.new(graph, v_to_undo, prev_id))
		controller.link_order.pop_back()
		controller.link_head = (
			controller.link_order.back()
			if not controller.link_order.is_empty()
			else Globals.NOT_FOUND
		)
		controller.sync_link_session_from_order()
		controller.refresh_link_buffer_colors()
		return

	controller.link_order.append(id)
	if head != Globals.NOT_FOUND and head != id and controller.should_add_connection(head, id):
		CommandManager.execute(AddEdgeCommand.new(graph, head, id))
	controller.sync_link_session_from_order()
	controller.link_head = id
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

func _handle_mouse_movement(_event: InputEventMouseMotion) -> void:
	var mouse_world_pos := controller.graph.get_global_mouse_position()

	# Cursor feedback every frame regardless of interaction mode.
	_handle_hover(mouse_world_pos)

	# Active interaction — resize beats normal drag; they can't both be true.
	if _is_resizing:
		_apply_resize(mouse_world_pos)
	elif controller.is_dragging and _has_last_mouse_world_pos:
		_handle_dragging(mouse_world_pos - _last_mouse_world_pos)

	_last_mouse_world_pos = mouse_world_pos
	_has_last_mouse_world_pos = true

	_sync_ghost_edge_preview()


func _handle_dragging(world_delta: Vector2) -> void:
	# Use world-space delta so the drag feels identical at any zoom level.
	for v in controller.drag_snapshot.keys():
		v.pos += world_delta
		v.z_idx = controller.VERTEX_ON_TOP
	controller.update_selection_bounds()


func _handle_hover(mouse_world_pos: Vector2) -> void:
	# Resize handles sit on the selection boundary — check them before vertices.
	var handle := _get_handle_at(mouse_world_pos)
	if handle != ResizeHandle.NONE:
		DisplayServer.cursor_set_shape(_get_cursor_for_handle(handle))
		return

	var over_vertex    := controller.graph.get_vertex_id_at(mouse_world_pos) != Globals.NOT_FOUND
	var over_selection := not controller.selection_buffer.is_empty() and \
						  controller.selection_bounds.has_point(mouse_world_pos)

	if over_vertex or over_selection:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_MOVE)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


# ----------------------------------------------------------------------------
# Bounding-box resize
# ----------------------------------------------------------------------------
#
# The user grabs a corner or edge handle on the selection bounding box and
# drags to scale all selected vertex POSITIONS relative to the box center.
# Vertex sizes never change — only their coordinates.
#
# Key design choices:
#   • Positions are always re-derived from the snapshot each frame, never
#     accumulated from deltas, so there is zero floating-point drift.
#   • On release a single MoveSelectionCommand is pushed, making the whole
#     resize one undo step.
#   • The click event is consumed (set_input_as_handled) so GlobalUI cannot
#     accidentally start a marquee rect on the same click.
#   • The grab-zone formula lives in GraphController.get_resize_grab_zone()
#     so MouseActions and GlobalUI always agree on which area is "on a handle".

## Returns which handle the given world position is over, or NONE.
## Requires ≥ 2 selected vertices — a single vertex has no relative layout to scale.
func _get_handle_at(world_pos: Vector2) -> ResizeHandle:
	if controller.selection_buffer.size() < 2:
		return ResizeHandle.NONE
	var bounds := controller.selection_bounds
	if bounds == Rect2():
		return ResizeHandle.NONE

	var gz := controller.get_resize_grab_zone()
	var tl := bounds.position
	var tr := Vector2(bounds.end.x, bounds.position.y)
	var bl := Vector2(bounds.position.x, bounds.end.y)
	var br := bounds.end

	# Corners take priority — check them before edges.
	if abs(world_pos.x - tl.x) <= gz and abs(world_pos.y - tl.y) <= gz: return ResizeHandle.TOP_LEFT
	if abs(world_pos.x - tr.x) <= gz and abs(world_pos.y - tr.y) <= gz: return ResizeHandle.TOP_RIGHT
	if abs(world_pos.x - bl.x) <= gz and abs(world_pos.y - bl.y) <= gz: return ResizeHandle.BOTTOM_LEFT
	if abs(world_pos.x - br.x) <= gz and abs(world_pos.y - br.y) <= gz: return ResizeHandle.BOTTOM_RIGHT

	# Edges: within gz perpendicular to the line, anywhere along its length.
	var in_x := world_pos.x >= tl.x - gz and world_pos.x <= tr.x + gz
	var in_y := world_pos.y >= tl.y - gz and world_pos.y <= bl.y + gz
	if abs(world_pos.y - tl.y) <= gz and in_x: return ResizeHandle.TOP
	if abs(world_pos.y - bl.y) <= gz and in_x: return ResizeHandle.BOTTOM
	if abs(world_pos.x - tl.x) <= gz and in_y: return ResizeHandle.LEFT
	if abs(world_pos.x - tr.x) <= gz and in_y: return ResizeHandle.RIGHT

	return ResizeHandle.NONE


## Maps each handle to the standard OS resize cursor so users know what
## direction they're about to drag before they press the mouse button.
func _get_cursor_for_handle(handle: ResizeHandle) -> DisplayServer.CursorShape:
	match handle:
		ResizeHandle.TOP_LEFT,  ResizeHandle.BOTTOM_RIGHT: return DisplayServer.CURSOR_FDIAGSIZE
		ResizeHandle.TOP_RIGHT, ResizeHandle.BOTTOM_LEFT:  return DisplayServer.CURSOR_BDIAGSIZE
		ResizeHandle.LEFT,      ResizeHandle.RIGHT:         return DisplayServer.CURSOR_HSIZE
		ResizeHandle.TOP,       ResizeHandle.BOTTOM:        return DisplayServer.CURSOR_VSIZE
	return DisplayServer.CURSOR_ARROW


## Locks in the starting state for the drag: which handle, the initial bounds,
## the pivot center, and a position snapshot of every selected vertex.
func _start_resize(handle: ResizeHandle) -> void:
	_is_resizing = true
	controller.is_resizing = true
	_resize_handle = handle
	_resize_initial_bounds = controller.selection_bounds
	_resize_center = _resize_initial_bounds.get_center()
	_resize_snapshot.clear()
	for v in controller.selection_buffer:
		_resize_snapshot[v] = v.pos


## Converts a mouse offset (distance from pivot) along one axis into a scale factor.
## Returns 1.0 on a degenerate (zero-width/height) axis so it stays unchanged.
func _scale_from_mouse(mouse_offset: float, half_extent: float) -> float:
	const MIN_SCALE := 0.05  # prevents collapsing to a point or flipping
	if half_extent < 0.5:
		return 1.0
	return clampf(mouse_offset / half_extent, MIN_SCALE, 100.0)


## Resolves the (sx, sy) scale pair for the active handle.
## Pre-computes the four directional offsets so each match arm stays readable.
func _compute_resize_scale(mouse_pos: Vector2, c: Vector2, hw: float, hh: float) -> Vector2:
	var rx := mouse_pos.x - c.x  # right of center
	var lx := c.x - mouse_pos.x  # left of center (inverted for left-side handles)
	var by := mouse_pos.y - c.y  # below center
	var ty := c.y - mouse_pos.y  # above center (inverted for top-side handles)
	match _resize_handle:
		ResizeHandle.RIGHT:        return Vector2(_scale_from_mouse(rx, hw), 1.0)
		ResizeHandle.LEFT:         return Vector2(_scale_from_mouse(lx, hw), 1.0)
		ResizeHandle.BOTTOM:       return Vector2(1.0, _scale_from_mouse(by, hh))
		ResizeHandle.TOP:          return Vector2(1.0, _scale_from_mouse(ty, hh))
		ResizeHandle.BOTTOM_RIGHT: return Vector2(_scale_from_mouse(rx, hw), _scale_from_mouse(by, hh))
		ResizeHandle.BOTTOM_LEFT:  return Vector2(_scale_from_mouse(lx, hw), _scale_from_mouse(by, hh))
		ResizeHandle.TOP_RIGHT:    return Vector2(_scale_from_mouse(rx, hw), _scale_from_mouse(ty, hh))
		ResizeHandle.TOP_LEFT:     return Vector2(_scale_from_mouse(lx, hw), _scale_from_mouse(ty, hh))
	return Vector2.ONE


## Repositions every selected vertex by applying the current scale to its
## offset from the pivot. Re-derived from the snapshot each frame (not delta-
## accumulated) so there is no floating-point drift over long drags.
func _apply_resize(mouse_world_pos: Vector2) -> void:
	var c  := _resize_center
	var hw := _resize_initial_bounds.end.x - c.x  # half-width at drag start
	var hh := _resize_initial_bounds.end.y - c.y  # half-height at drag start
	var scale := _compute_resize_scale(mouse_world_pos, c, hw, hh)

	for v: Vertex in _resize_snapshot.keys():
		var rel: Vector2 = _resize_snapshot[v] - c
		v.pos = c + Vector2(rel.x * scale.x, rel.y * scale.y)

	controller.update_selection_bounds()


## Finalises the resize: clears the session and records an undo entry only
## if vertices actually moved (a click-without-drag should leave history clean).
func _stop_resize() -> void:
	if not _is_resizing:
		return
	_is_resizing = false
	controller.is_resizing = false

	var has_moved := false
	for v: Vertex in _resize_snapshot.keys():
		if v.pos != _resize_snapshot[v]:
			has_moved = true
			break

	if has_moved:
		CommandManager.push_to_stack(MoveSelectionCommand.new(_resize_snapshot, controller))

	_resize_snapshot.clear()
	_resize_handle = ResizeHandle.NONE
