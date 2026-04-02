# PopupMenuManager
# -----------------------------------------------------------------------------
# Central UI overlay that builds and opens context menus for graph objects.
# SOLID goals:
# - GraphController decides what was clicked (vertex/edge/canvas).
# - PopupMenuManager decides what menu to show and how to build it.
# - Commands hold the logic + undo/redo integration (CommandManager).
#
# Menu definition format (nested Array):
# [
#   ["Label", Command_instance],
#   ["Label", [ submenu items... ]],
#   ["Label", null],                  # placeholder (no action)
# ]
#
# IMPORTANT:
# - Every PopupMenu (main AND submenus) emits its own "index_pressed".
#   So we must connect handlers for submenus too, not only MainMenu.
# -----------------------------------------------------------------------------
class_name GraphContextMenuManager
extends Control

# SIGNALS
signal run_algorithm(algorithm: AlgorithmPlayer.ALGORITHMS, start_node: Vertex)
signal toggle_grid_requested(enabled: bool)

const LOG_TAG = "POPUP_MENU"

@onready var MainMenu: PopupMenu = $MainMenu

# The graph the commands operate on.
# We inject it from GraphController in _ready().
var graph: Graph

# Save the controller in order to access its properties
var controller: GraphController 


const ALGORITHM_MENU_ITEMS := [
	{"label": "BFS", "id": AlgorithmPlayer.ALGORITHMS.BFS},
	{"label": "DFS", "id": AlgorithmPlayer.ALGORITHMS.DFS},
	{"label": "Dijkstra", "id": AlgorithmPlayer.ALGORITHMS.DIJKSTRA},
	{"label": "Prim's MST", "id": AlgorithmPlayer.ALGORITHMS.PRIM},
	{"label": "Kruskal's MST", "id": AlgorithmPlayer.ALGORITHMS.KRUSKAL},
]

# Helper to generate the color square icon
func _get_swatch(c: Color) -> Texture2D:
	return IconGenerator.make_color_swatch(c)
	
	
# Active context (what was clicked)
var active = null
var mode: String = "general"
var _is_grid_enabled := false

# We create submenu PopupMenus dynamically on each open.
# Store them so we can free them next time (avoid leaks / duplicates).
var _dynamic_menus: Array[PopupMenu] = []

func _ready() -> void:
	if MainMenu:
			_wire_menu(MainMenu)
			_apply_excalidraw_style(MainMenu)


func _apply_excalidraw_style(menu: PopupMenu) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.WHITE
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(0.878, 0.878, 0.878)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_right = 8
	panel.corner_radius_bottom_left = 8
	panel.shadow_color = Color(0, 0, 0, 0.14)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 2)
	panel.content_margin_left = 4.0
	panel.content_margin_top = 4.0
	panel.content_margin_right = 4.0
	panel.content_margin_bottom = 4.0
	menu.add_theme_stylebox_override("panel", panel)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.906, 0.922, 0.988)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_right = 6
	hover.corner_radius_bottom_left = 6
	hover.content_margin_left = 8.0
	hover.content_margin_top = 4.0
	hover.content_margin_right = 8.0
	hover.content_margin_bottom = 4.0
	menu.add_theme_stylebox_override("hover", hover)

	menu.add_theme_color_override("font_color", Color(0.118, 0.118, 0.18))
	menu.add_theme_color_override("font_hover_color", Color(0.263, 0.38, 0.933))
	menu.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.7))
	menu.add_theme_color_override("font_separator_color", Color(0.6, 0.6, 0.65))
	menu.add_theme_font_size_override("font_size", 14)
	menu.add_theme_constant_override("item_start_padding", 12)
	menu.add_theme_constant_override("item_end_padding", 12)
	menu.add_theme_constant_override("v_separation", 4)
			
		
# -----------------------------------------------------------------------------
# PUBLIC API: GraphController calls exactly ONE of these
# -----------------------------------------------------------------------------

func open_for_vertex(v: Vertex, mouse_pos_world: Vector2, mouse_pos_screen: Vector2 = get_viewport().get_mouse_position()) -> void:
	active = v
	mode = "vertex"
	_open_at(mouse_pos_screen, _make_vertex_menu(v, mouse_pos_world))

func open_for_edge(e: Edge, _mouse_pos_world: Vector2, mouse_pos_screen: Vector2 = get_viewport().get_mouse_position()) -> void:
	active = e
	mode = "edge"
	_open_at(mouse_pos_screen, _make_edge_menu(e))

func open_for_canvas(mouse_pos_world: Vector2, mouse_pos_screen: Vector2 = get_viewport().get_mouse_position()) -> void:
	active = null
	mode = "general"
	_open_at(mouse_pos_screen, _make_canvas_menu(mouse_pos_world))

func open_for_selection(clicked_vertex: Vertex, mouse_pos_world: Vector2, mouse_pos_screen: Vector2 = get_viewport().get_mouse_position()) -> void:
	active = clicked_vertex
	mode = "selection"
	_open_at(mouse_pos_screen, _make_selection_menu(clicked_vertex, mouse_pos_world))


# -----------------------------------------------------------------------------
# OPEN + BUILD
# -----------------------------------------------------------------------------

## Opens the main popup at a specific position, rebuilds all items.
func _open_at(mouse_pos: Vector2, menu_def: Array) -> void:
	# 1. Clean old dynamically-created submenus (critical)
	_clear_dynamic_menus()

	# 2. Build menu tree recursively (MainMenu + all submenus)
	_build_menu_recursive(MainMenu, menu_def)

	# 3. Show the main menu at mouse position
	# PopupMenu inherits Popup, and popup(rect) is the clean way to place it.
	MainMenu.popup(Rect2i(Vector2i(mouse_pos), Vector2i.ZERO))


## Recursively builds menu items and submenu nodes.
func _build_menu_recursive(menu: PopupMenu, menu_def: Array) -> void:
	# Clean slate
	menu.clear()

	# Loop entries like: ["Delete", Command] or ["Algorithms", [...]] etc.
	for item in menu_def:
		var label = item[0]
		var value = item[1] if item.size() > 1 else null # allow ["test"] too
		var icon  = item[2] if item.size() > 2 else null # Icon

		# Add seperator
		if label == "---":
				menu.add_separator()
				continue # Skip the rest of the loop for this item
				
		# CASE 1: Callable -> clickable item
		if value is Callable:
			var idx = menu.item_count
			menu.add_item(label)
			menu.set_item_metadata(idx,value)

			if icon:
				menu.set_item_icon(idx,icon)

		# CASE 2: Real Command instance -> clickable item
		elif value is Command:
			var idx = menu.item_count
			menu.add_item(label)
			menu.set_item_metadata(idx, value) # store command object here
			
			if icon:
				menu.set_item_icon(idx, icon)

		# CASE 2: Submenu -> nested Array
		elif value is Array:
			var submenu := PopupMenu.new()
			submenu.name = item[0]
			menu.add_child(submenu)

			# Track dynamic menus so we can free them next open
			_dynamic_menus.append(submenu)

			# Wire submenu clicks too (very important)
			_wire_menu(submenu)
			_apply_excalidraw_style(submenu)

			# Link submenu to this item (Godot handles submenu UI behavior)
			menu.add_submenu_node_item(label, submenu)

			# Fill submenu contents
			_build_menu_recursive(submenu, value)

			# Optional UX: hide submenu when mouse exits it
			# (You wanted this behavior)
			#submenu.mouse_exited.connect(func(): submenu.hide())

		# CASE 3: Placeholder / missing command / debug
		else:
			var idx = menu.item_count
			menu.add_item(label)
			menu.set_item_metadata(idx, null) # no action
			
			if value == null:
				menu.set_item_disabled(idx, true)


# Connects a PopupMenu's clicks to a handler that reads metadata and executes command.
func _wire_menu(menu: PopupMenu) -> void:
	# Avoid double-connecting if you ever reuse menus
	if menu.index_pressed.is_connected(_on_any_menu_item_pressed):
		return
	menu.index_pressed.connect(_on_any_menu_item_pressed.bind(menu))


# This runs for MainMenu AND for any submenu.
# We get the clicked menu instance + index, then fetch metadata from that menu.
func _on_any_menu_item_pressed(index: int, menu: PopupMenu) -> void:
	var cmd = menu.get_item_metadata(index)

	# Placeholder: do nothing (but keep it safe and debuggable)
	if cmd == null:
		GLogger.debug("Popup placeholder clicked: '%s' (mode=%s)" % [menu.get_item_text(index), mode],LOG_TAG)
		return

	# Real command: execute through CommandManager so undo/redo works
	if cmd is Command:
		CommandManager.execute(cmd)
		return

	if cmd is Callable:
		cmd.call()
		return
		
	
	# If someone accidentally stored something else, fail safely
	push_warning("Popup item metadata not recognized: %s" % [str(cmd)])


func _clear_dynamic_menus() -> void:
	# Free previously created submenu nodes
	for m in _dynamic_menus:
		if is_instance_valid(m):
			m.queue_free()
	_dynamic_menus.clear()


func _clear_context() -> void:
	active = null
	mode = "general"


# -----------------------------------------------------------------------------
# MENU FACTORIES (ALL MENUS DEFINED HERE, SOLID)
# -----------------------------------------------------------------------------


func _make_vertex_menu(v: Vertex, mouse_pos: Vector2) -> Array:
	# Determine if we call paste
	var paste_cmd = null
	if Globals.clipboard_graph != null:
		paste_cmd = PasteCommand.new(graph, Globals.clipboard_graph, mouse_pos, controller)

	# You can put placeholders (null) while implementing commands.
	# This lets you test menu opening immediately.
	var buffer_snapshot = controller.selection_buffer.duplicate() if controller else []
	if buffer_snapshot.is_empty() and v:
		buffer_snapshot = [v]

	var color_vertex_submenu = [
	["Black",  ChangeVertexColorCommand.new(v, Color.BLACK),  _get_swatch(Color.BLACK)],
	["Red",    ChangeVertexColorCommand.new(v, Color.RED),    _get_swatch(Color.RED)],
	["Blue",   ChangeVertexColorCommand.new(v, Color.BLUE),   _get_swatch(Color.BLUE)],
	["White",  ChangeVertexColorCommand.new(v, Color.WHITE),  _get_swatch(Color.WHITE)],
	["Yellow", ChangeVertexColorCommand.new(v, Color.YELLOW), _get_swatch(Color.YELLOW)],
	["Green",  ChangeVertexColorCommand.new(v, Color.GREEN),  _get_swatch(Color.GREEN)]
	]	


	return [
			# Color
			["Color Vertex", color_vertex_submenu], 
			["---", null],

			# ClipBoard
			["Copy", CopyCommand.new(graph, buffer_snapshot)],
			["Paste", paste_cmd],
			["Cut", CutCommand.new(graph, buffer_snapshot, controller)],
			["---", null],

			# Delete
			["Delete Vertex", DeleteVertexCommand.new(graph, v)]
		]
	


func _make_edge_menu(e: Edge) -> Array:
	# 1. Create the Submenu for Colors
	var color_edge_submenu = [
		["Black",  ChangeEdgeColorCommand.new(e, Color.BLACK),  _get_swatch(Color.BLACK)],
		["Red",    ChangeEdgeColorCommand.new(e, Color.RED),    _get_swatch(Color.RED)],
		["Blue",   ChangeEdgeColorCommand.new(e, Color.BLUE),   _get_swatch(Color.BLUE)],
		["White",  ChangeEdgeColorCommand.new(e, Color.WHITE),  _get_swatch(Color.WHITE)],
		["Yellow", ChangeEdgeColorCommand.new(e, Color.YELLOW), _get_swatch(Color.YELLOW)],
		["Green",  ChangeEdgeColorCommand.new(e, Color.GREEN),  _get_swatch(Color.GREEN)]
	]

	# 2. Return the Main Edge Menu
	return [		
		# Add the submenu here
		["Color Edge", color_edge_submenu],
		["---", null],

		["Delete Edge", DeleteEdgeCommand.new(graph, e.src.id, e.dst.id)],
	]

func _make_canvas_menu(mouse_pos: Vector2) -> Array:
	var paste_cmd = null
	if Globals.clipboard_graph != null:
		paste_cmd = PasteCommand.new(graph, Globals.clipboard_graph, mouse_pos, controller)

	return [
			["Create Vertex", AddVertexCommand.new(graph, mouse_pos)],
			["Paste", paste_cmd],
			["---", null],
			[_grid_toggle_menu_label(), func(): _toggle_grid_from_menu()]
		]

func _make_selection_menu(clicked_vertex: Vertex, mouse_pos: Vector2) -> Array:
	var selection_snapshot: Array[Vertex] = controller.selection_buffer.duplicate() if controller else []
	var paste_cmd = null
	if Globals.clipboard_graph != null:
		paste_cmd = PasteCommand.new(graph, Globals.clipboard_graph, mouse_pos, controller)

	var algo_submenu := []
	for entry in ALGORITHM_MENU_ITEMS:
		var algo_name: String = entry["label"]
		var algorithm: AlgorithmPlayer.ALGORITHMS = entry["id"] as AlgorithmPlayer.ALGORITHMS
		var cmd = null
		if not selection_snapshot.is_empty():
			cmd = func(): run_algorithm.emit(algorithm, clicked_vertex)
		algo_submenu.append([algo_name, cmd])

	var color_vertices_submenu = _build_color_vertices_selection_submenu(selection_snapshot)
	var color_edges_submenu = _build_color_edges_selection_submenu(selection_snapshot)
	var delete_selection_cmd = DeleteSelectionCommand.new(graph, selection_snapshot, controller) if not selection_snapshot.is_empty() else null

	return [
		["Algorithms", algo_submenu],
		["---", null],
		["Copy", CopyCommand.new(graph, selection_snapshot)],
		["Paste", paste_cmd],
		["Cut", CutCommand.new(graph, selection_snapshot, controller)],
		["---", null],
		["Color Vertices", color_vertices_submenu],
		["Color Edges", color_edges_submenu],
		["---", null],
		["Delete Selection", delete_selection_cmd]
	]

func _build_color_vertices_selection_submenu(selection_vertices: Array[Vertex]) -> Array:
	if selection_vertices.is_empty():
		return [["No vertices in selection", null]]
	return [
		["Black",  ChangeSelectionVertexColorCommand.new(selection_vertices, Color.BLACK),  _get_swatch(Color.BLACK)],
		["Red",    ChangeSelectionVertexColorCommand.new(selection_vertices, Color.RED),    _get_swatch(Color.RED)],
		["Blue",   ChangeSelectionVertexColorCommand.new(selection_vertices, Color.BLUE),   _get_swatch(Color.BLUE)],
		["White",  ChangeSelectionVertexColorCommand.new(selection_vertices, Color.WHITE),  _get_swatch(Color.WHITE)],
		["Yellow", ChangeSelectionVertexColorCommand.new(selection_vertices, Color.YELLOW), _get_swatch(Color.YELLOW)],
		["Green",  ChangeSelectionVertexColorCommand.new(selection_vertices, Color.GREEN),  _get_swatch(Color.GREEN)]
	]

func _build_color_edges_selection_submenu(selection_vertices: Array[Vertex]) -> Array:
	var edges := _get_edges_within_selection(selection_vertices)
	if edges.is_empty():
		return [["No edges in selection", null]]
	return [
		["Black",  ChangeSelectionEdgeColorCommand.new(edges, Color.BLACK),  _get_swatch(Color.BLACK)],
		["Red",    ChangeSelectionEdgeColorCommand.new(edges, Color.RED),    _get_swatch(Color.RED)],
		["Blue",   ChangeSelectionEdgeColorCommand.new(edges, Color.BLUE),   _get_swatch(Color.BLUE)],
		["White",  ChangeSelectionEdgeColorCommand.new(edges, Color.WHITE),  _get_swatch(Color.WHITE)],
		["Yellow", ChangeSelectionEdgeColorCommand.new(edges, Color.YELLOW), _get_swatch(Color.YELLOW)],
		["Green",  ChangeSelectionEdgeColorCommand.new(edges, Color.GREEN),  _get_swatch(Color.GREEN)]
	]

func _get_edges_within_selection(selection_vertices: Array[Vertex]) -> Array[Edge]:
	var unique_edges: Array[Edge] = []
	var selected_ids := {}
	var seen_keys := {}

	for v in selection_vertices:
		selected_ids[v.id] = true

	for v in selection_vertices:
		var e = v.edges
		while e:
			if selected_ids.has(e.dst.id):
				var key := ""
				if e.strategy is UndirectedStrategy:
					var a := mini(e.src.id, e.dst.id)
					var b := maxi(e.src.id, e.dst.id)
					key = "U:%d-%d" % [a, b]
				else:
					key = "D:%d>%d" % [e.src.id, e.dst.id]

				if not seen_keys.has(key):
					seen_keys[key] = true
					unique_edges.append(e)
			e = e.next

	return unique_edges

func _grid_toggle_menu_label() -> String:
	# Use popup shortcut column so the icon appears on the far right.
	return "Toggle Grid\t✓" if _is_grid_enabled else "Toggle Grid"

func _toggle_grid_from_menu() -> void:
	_is_grid_enabled = not _is_grid_enabled
	toggle_grid_requested.emit(_is_grid_enabled)


func find_vertex_view(node: Node) -> UIVertexView:
	var current = node
	while current:
		if current is UIVertexView:
			return current
		current = current.get_parent()
	return null


func pick_at_position(pos: Vector2) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Returns ALL colliders at this point (sorted by Z & proximity)
	var results: Array = space_state.intersect_point(query)

	if results.is_empty():
		print("Clicked empty space")
		return

	# Closest / top-most hit
	var hit = results[0]

	var v = find_vertex_view(hit["collider"])
	if v:
		open_for_vertex(v.vertex_data, pos)
	print("Clicked collider:", find_vertex_view(hit["collider"]))
