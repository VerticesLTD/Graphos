## Orchestrates all persistence: auto-save, explicit save/load, startup restore.
##
## Add as a child of the main scene and wire the @export refs in the Inspector.
## This node owns no serialization logic — it delegates to GraphDocumentIO,
## GraphSerializer, and AppStateSerializer from core/persistence/.
##
## Keyboard shortcuts (defined in Project Settings → Input Map):
##   Ctrl+S          → save_file      (save to current path or autosave)
##   Ctrl+Shift+S    → save_file_as   (always open Save dialog)
##   Ctrl+O          → open_file      (open Load dialog)
extends Node
class_name PersistenceManager

@export var graph: Graph
@export var camera: Camera2D
@export var grid_background: MathGridBackground
@export var popup_menu_a: GraphContextMenuManager  ## GraphController/PopupMenu
@export var popup_menu_b: GraphContextMenuManager  ## CanvasLayer/PopupMenuLayer

## Resolved at _ready() — ShareManager runs its _ready() first (scene order).
@onready var _share_manager: ShareManager = get_node_or_null("../ShareManager") as ShareManager

var _auto_save: AutoSaveService
## Path of the last explicitly saved/opened file.  Empty = no named file yet.
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

	var loaded_from_url := _share_manager != null and _share_manager.loaded_from_url
	if not loaded_from_url:
		_try_load_autosave()
	else:
		# Graph came from a share URL — treat it as a temporary sandbox.
		# The user can edit freely but nothing is written to their IndexedDB,
		# so closing the tab leaves their own graph completely untouched.
		_auto_save.pause()


func _input(event: InputEvent) -> void:
	# File dialogs are desktop-only — on web the OS filesystem is not accessible.
	if OS.has_feature("web"):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("save_file_as"):
		_open_save_dialog()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save_file"):
		var path := _current_path if not _current_path.is_empty() else GraphDocumentIO.AUTOSAVE_PATH
		_save(path)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_file"):
		_open_load_dialog()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func _save(path: String) -> void:
	var ok := GraphDocumentIO.save(graph, camera, grid_background.grid_enabled, path)
	if not ok:
		Notify.show_error("Save failed.")
		return
	if path != GraphDocumentIO.AUTOSAVE_PATH:
		_current_path = path
		Notify.show_notification("Saved: " + path.get_file())


func _on_auto_save_requested() -> void:
	var path := _current_path if not _current_path.is_empty() else GraphDocumentIO.AUTOSAVE_PATH
	GraphDocumentIO.save(graph, camera, grid_background.grid_enabled, path)


func _on_grid_toggled(_enabled: bool) -> void:
	_auto_save.mark_dirty()


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

func _try_load_autosave() -> void:
	if FileAccess.file_exists(GraphDocumentIO.AUTOSAVE_PATH):
		_load(GraphDocumentIO.AUTOSAVE_PATH)


func _load(path: String) -> void:
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


## Permanently pause autosave for this session.
## Called by ShareManager when a graph is loaded from a URL hash so the
## user's own IndexedDB is never overwritten by a shared graph.
func suspend_autosave() -> void:
	if _auto_save:
		_auto_save.pause()


## Apply a fully-parsed document dictionary to the scene.
## Called by _load() for file-based loading, and by ShareManager when
## restoring from a URL hash.  Safe to call before _auto_save is initialised.
func apply_document(result: Dictionary) -> void:
	if not graph or not camera or not grid_background:
		push_error("PersistenceManager: missing node refs — cannot apply document.")
		return

	# _auto_save may be null when called by ShareManager before our own _ready().
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

	if _auto_save != null:
		_auto_save.resume()


# ---------------------------------------------------------------------------
# File dialogs
# ---------------------------------------------------------------------------

func _open_save_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.%s ; Graphos Files" % GraphDocumentIO.FILE_EXTENSION])
	dialog.file_selected.connect(func(p: String) -> void:
		_save(p)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _open_load_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.%s ; Graphos Files" % GraphDocumentIO.FILE_EXTENSION])
	dialog.file_selected.connect(func(p: String) -> void:
		_load(p)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))
