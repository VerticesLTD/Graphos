## Orchestrates all persistence: auto-save, explicit save/load, startup restore.
##
## Multi-graph model:
##   - Each graph has a stable graphId stored in user://graphs/<id>.graphos
##   - The last opened ID is tracked in user://graphs/index.json
##   - auto-save always writes to the active graph's file
##
## Startup sequence:
##   1. ShareManager._ready() runs first (scene order).  It may set:
##        loaded_from_url = true    →  graph already applied, just set active ID
##        pending_conflict = {...}  →  show conflict dialog, then proceed normally
##   2. PersistenceManager._ready() runs:
##        • Handles pending_conflict if present (deferred dialog)
##        • Otherwise loads the last opened graph or creates a new one
##
## Keyboard shortcuts (defined in Project Settings → Input Map):
##   Ctrl+S          → save_file      (desktop only)
##   Ctrl+Shift+S    → save_file_as   (desktop only)
##   Ctrl+O          → open_file      (desktop only)
extends Node
class_name PersistenceManager

@export var graph: Graph
@export var camera: Camera2D
@export var grid_background: MathGridBackground
@export var popup_menu_a: GraphContextMenuManager
@export var popup_menu_b: GraphContextMenuManager

@onready var _share_manager: ShareManager = get_node_or_null("../ShareManager") as ShareManager

var _auto_save: AutoSaveService
var _active_graph_id: String = ""
## Desktop-only: path of the last explicitly saved/opened named file.
var _current_path: String = ""


func _ready() -> void:
	_auto_save = AutoSaveService.new()
	add_child(_auto_save)
	_auto_save.save_requested.connect(_on_auto_save_requested)

	CommandManager.state_changed.connect(_auto_save.mark_dirty)

	if camera:
		camera.view_changed.connect(_auto_save.mark_dirty)

	if popup_menu_a:
		popup_menu_a.toggle_grid_requested.connect(_on_grid_toggled)
	if popup_menu_b:
		popup_menu_b.toggle_grid_requested.connect(_on_grid_toggled)

	Globals.strategy_changed.connect(_auto_save.mark_dirty)
	Globals.weighted_mode_changed.connect(_auto_save.mark_dirty)

	var loaded_from_url  := _share_manager != null and _share_manager.loaded_from_url
	var has_conflict     := _share_manager != null and not _share_manager.pending_conflict.is_empty()

	if has_conflict:
		# Load the user's own graph normally so they have something to work with,
		# then surface the conflict dialog on the next frame.
		_load_startup_graph()
		call_deferred("_show_conflict_dialog", _share_manager.pending_conflict)
	elif loaded_from_url:
		# ShareManager already applied the graph; just wire up the active ID
		# (set_active_graph_id was already called by ShareManager).
		pass
	else:
		_load_startup_graph()


func _input(event: InputEvent) -> void:
	if OS.has_feature("web"):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("save_file_as"):
		_open_save_dialog()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save_file"):
		var path := _current_path if not _current_path.is_empty() \
				else GraphDocumentIO.AUTOSAVE_PATH
		_save_to_path(path)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_file"):
		_open_load_dialog()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Active graph identity
# ---------------------------------------------------------------------------

func get_active_graph_id() -> String:
	return _active_graph_id


## Set the active graph ID, persist it to the index, and sync the browser URL.
## This is the single authoritative place to record a graph switch.
func set_active_graph_id(graph_id: String) -> void:
	_active_graph_id = graph_id
	if not graph_id.is_empty():
		GraphStore.set_last_opened_id(graph_id)
	if _share_manager:
		_share_manager.sync_url_to_graph_id(graph_id)


# ---------------------------------------------------------------------------
# Startup graph loading
# ---------------------------------------------------------------------------

func _load_startup_graph() -> void:
	# Step 1: migrate legacy single-file autosave if present.
	var migrated_id := GraphStore.migrate_legacy_autosave()
	if not migrated_id.is_empty():
		var result := GraphStore.load_graph(migrated_id)
		if not result.is_empty():
			apply_document(result)
			set_active_graph_id(migrated_id)
			return

	# Step 2: restore the last opened graph.
	var last_id := GraphStore.get_last_opened_id()
	if not last_id.is_empty() and GraphStore.exists(last_id):
		var result := GraphStore.load_graph(last_id)
		if not result.is_empty():
			apply_document(result)
			set_active_graph_id(last_id)
			return

	# Step 3: no graphs exist — create a new empty default graph.
	_create_new_graph()


func _create_new_graph() -> void:
	var new_id := GraphStore.generate_unique_id()
	# Graph node is already empty at scene start; just save it.
	var doc := GraphDocumentIO.build_document(graph, camera, grid_background.grid_enabled, new_id)
	GraphStore.save(new_id, doc)
	set_active_graph_id(new_id)
	CommandManager.clear_history()


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func _on_auto_save_requested() -> void:
	_auto_save_to_store()


func _auto_save_to_store() -> void:
	if _active_graph_id.is_empty():
		return
	var doc := GraphDocumentIO.build_document(
			graph, camera, grid_background.grid_enabled, _active_graph_id)
	GraphStore.save(_active_graph_id, doc)


func _on_grid_toggled(_enabled: bool) -> void:
	_auto_save.mark_dirty()


## Desktop-only: save to a named file path.
func _save_to_path(path: String) -> void:
	var ok := GraphDocumentIO.save(
			graph, camera, grid_background.grid_enabled, path, _active_graph_id)
	if not ok:
		Notify.show_error("Save failed.")
		return
	if path != GraphDocumentIO.AUTOSAVE_PATH:
		_current_path = path
		Notify.show_notification("Saved: " + path.get_file())


# ---------------------------------------------------------------------------
# Duplicate / Save as new graph
# ---------------------------------------------------------------------------

## Duplicate the current graph: assign a new graphId, save, and make it active.
## The original graph is left unchanged.
func save_as_new_graph() -> void:
	var new_id := GraphStore.generate_unique_id()
	var doc    := GraphDocumentIO.build_document(
			graph, camera, grid_background.grid_enabled, new_id)
	if not GraphStore.save(new_id, doc):
		Notify.show_error("Could not save duplicate graph.")
		return
	set_active_graph_id(new_id)
	Notify.show_notification("Saved as new graph.")


# ---------------------------------------------------------------------------
# Autosave control (called externally)
# ---------------------------------------------------------------------------

## Permanently suspend autosave for this session.
func suspend_autosave() -> void:
	if _auto_save:
		_auto_save.pause()


## Resume autosave (e.g. after a live hashchange load).
func resume_autosave() -> void:
	if _auto_save:
		_auto_save.resume()


# ---------------------------------------------------------------------------
# Apply a parsed document to the live scene
# ---------------------------------------------------------------------------

## Apply a fully-parsed document dictionary to the scene.
## Sets _active_graph_id from the result if it contains a "graph_id" key.
## Safe to call before _auto_save is initialised (ShareManager calls this early).
func apply_document(result: Dictionary) -> void:
	if not graph or not camera or not grid_background:
		push_error("PersistenceManager: missing node refs — cannot apply document.")
		return

	if _auto_save != null:
		_auto_save.pause()

	GraphSerializer.from_dictionary(result["graph_data"], graph)

	var state: Dictionary = result["app_state"]

	camera.position = state["camera_position"]
	var zoom_val: float = state["camera_zoom"]
	camera._target_zoom = zoom_val
	camera.zoom = Vector2(zoom_val, zoom_val)

	var grid_on: bool = state["grid_enabled"]
	grid_background.set_grid_enabled(grid_on)
	if popup_menu_a:
		popup_menu_a.sync_grid_state(grid_on)
	if popup_menu_b:
		popup_menu_b.sync_grid_state(grid_on)

	if state["active_strategy"] == "directed":
		Globals.active_strategy = DirectedStrategy.new()
	else:
		Globals.active_strategy = UndirectedStrategy.new()
	Globals.is_weighted_mode = state["is_weighted_mode"]

	Globals.current_state = Globals.State.SELECTION
	CommandManager.clear_history()

	# Honour the graph_id embedded in the result when provided.
	var doc_id: String = result.get("graph_id", "")
	if not doc_id.is_empty():
		_active_graph_id = doc_id

	if _auto_save != null:
		_auto_save.resume()


# ---------------------------------------------------------------------------
# Conflict resolution dialog
# ---------------------------------------------------------------------------

func _show_conflict_dialog(conflict: Dictionary) -> void:
	var graph_id: String       = conflict.get("graph_id", "")
	var shared_doc: Dictionary = conflict.get("shared_doc", {})
	if graph_id.is_empty() or shared_doc.is_empty():
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Graph Already Exists"
	dialog.dialog_text = (
		"You opened a shared link for a graph that already exists in your\n"
		+ "local storage (ID: %s).\n\nWhat would you like to do?" % graph_id
	)
	dialog.ok_button_text = "Keep local version"
	var shared_btn := dialog.add_button("Open shared version", true, "open_shared")
	var copy_btn   := dialog.add_button("Save shared as new graph", true, "save_copy")
	# Suppress unused-variable warnings — buttons are referenced via signals.
	var _s := shared_btn
	var _c := copy_btn

	dialog.confirmed.connect(func() -> void:
		# "Keep local version" — the local graph is already loaded; nothing to do.
		dialog.queue_free()
	)

	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == "open_shared":
			# Overwrite the local file with the shared version and apply it.
			_persist_and_apply_shared(graph_id, shared_doc)
		elif action == "save_copy":
			# Generate a fresh ID guaranteed not to collide, make it active.
			var new_id := GraphStore.generate_unique_id()
			shared_doc["graph_id"] = new_id
			_persist_and_apply_shared(new_id, shared_doc)
		dialog.queue_free()
	)

	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(480, 0))


func _persist_and_apply_shared(graph_id: String, result: Dictionary) -> void:
	var raw_doc: Dictionary = result["graph_data"].duplicate(true)
	raw_doc["graph_id"] = graph_id
	GraphStore.save(graph_id, raw_doc)
	apply_document(result)
	set_active_graph_id(graph_id)


# ---------------------------------------------------------------------------
# Desktop file dialogs
# ---------------------------------------------------------------------------

func _open_save_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(
			["*.%s ; Graphos Files" % GraphDocumentIO.FILE_EXTENSION])
	dialog.file_selected.connect(func(p: String) -> void:
		_save_to_path(p)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _open_load_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(
			["*.%s ; Graphos Files" % GraphDocumentIO.FILE_EXTENSION])
	dialog.file_selected.connect(func(p: String) -> void:
		_load_from_path(p)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _load_from_path(path: String) -> void:
	if not graph or not camera or not grid_background:
		push_error("PersistenceManager: missing node refs — cannot load.")
		return
	var result := GraphDocumentIO.load(path)
	if result.is_empty():
		push_error("PersistenceManager: failed to load '%s'." % path)
		return
	if path != GraphDocumentIO.AUTOSAVE_PATH:
		_current_path = path
	apply_document(result)
