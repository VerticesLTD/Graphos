## Multi-graph storage layer.
##
## Stores each graph as an individual .graphos file under user://graphs/<id>.graphos
## and maintains a lightweight index file tracking the last opened graph ID.
##
## Pure static API — owns no state.  Delegates file-format concerns to
## GraphDocumentIO; only owns the directory layout and index bookkeeping.
extends RefCounted
class_name GraphStore

const GRAPHS_DIR         := "user://graphs/"
const INDEX_PATH         := "user://graphs/index.json"
const LEGACY_AUTOSAVE    := "user://autosave.graphos"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Ensure the graphs directory exists (safe to call repeatedly).
static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(GRAPHS_DIR)


## Write a raw document dictionary to disk under the given graph_id.
## The caller is responsible for including "graph_id" in the doc.
static func save(graph_id: String, doc: Dictionary) -> bool:
	ensure_dir()
	var path := _path_for(graph_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GraphStore: cannot write '%s' (error %d)." \
				% [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(doc, "\t"))
	file.close()
	return true


## Load and parse a stored graph.
## Returns { "graph_data", "graph_id", "app_state" } on success, or {} on failure.
static func load_graph(graph_id: String) -> Dictionary:
	return GraphDocumentIO.load(_path_for(graph_id))


## Returns true if a graph file for graph_id exists locally.
static func exists(graph_id: String) -> bool:
	return FileAccess.file_exists(_path_for(graph_id))


## Delete a graph file.  Silently succeeds if the file does not exist.
static func delete_graph(graph_id: String) -> void:
	var path := _path_for(graph_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Return all locally stored graph IDs (order is not guaranteed).
static func list_ids() -> Array[String]:
	ensure_dir()
	var ids: Array[String] = []
	var dir := DirAccess.open(GRAPHS_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".graphos"):
			ids.append(fname.trim_suffix(".graphos"))
		fname = dir.get_next()
	dir.list_dir_end()
	return ids


## Generate a graph ID guaranteed not to collide with any locally stored graph.
## In practice a single attempt always succeeds (48-bit collision space), but
## this loop is the correct pattern regardless.
static func generate_unique_id() -> String:
	var id := GraphIdUtil.generate()
	while exists(id):
		id = GraphIdUtil.generate()
	return id


## Return the ID of the most-recently opened graph, or "" if none recorded.
static func get_last_opened_id() -> String:
	return _load_index().get("last_opened_graph_id", "")


## Persist the most-recently opened graph ID.
static func set_last_opened_id(graph_id: String) -> void:
	var index := _load_index()
	index["last_opened_graph_id"] = graph_id
	_save_index(index)


## Migrate the legacy single-graph autosave file into the multi-graph store.
## Must be called before _load_startup_graph() during app init.
## Returns the assigned graph_id, or "" if no migration was needed.
static func migrate_legacy_autosave() -> String:
	if not FileAccess.file_exists(LEGACY_AUTOSAVE):
		return ""

	var raw := _raw_load(LEGACY_AUTOSAVE)
	if raw.is_empty():
		push_warning("GraphStore: legacy autosave exists but could not be parsed; skipping migration.")
		return ""

	# Assign a stable ID (legacy files have none).
	var graph_id: String = raw.get("graph_id", "")
	if graph_id.is_empty():
		graph_id = GraphIdUtil.generate()

	raw["graph_id"] = graph_id
	ensure_dir()
	if not save(graph_id, raw):
		push_error("GraphStore: failed to save migrated autosave as '%s'." % graph_id)
		return ""

	set_last_opened_id(graph_id)
	DirAccess.remove_absolute(LEGACY_AUTOSAVE)
	return graph_id


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _path_for(graph_id: String) -> String:
	return GRAPHS_DIR + graph_id + ".graphos"


## Load raw JSON from a path without processing through AppStateSerializer.
static func _raw_load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func _load_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX_PATH):
		return {}
	var text := FileAccess.get_file_as_string(INDEX_PATH)
	if text.is_empty():
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func _save_index(index: Dictionary) -> void:
	ensure_dir()
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
