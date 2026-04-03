## Reads and writes .graphos JSON documents (format_version 2).
##
## Combines GraphSerializer + AppStateSerializer into a single file format.
## Pure static API — owns no state, safe to call from any context.
##
## Document root shape:
##   {
##     "format_version": 2,
##     "next_vertex_id": int,
##     "vertices": [...],          # see GraphSerializer
##     "edges": [...],             # see GraphSerializer
##     "app_state": {              # see AppStateSerializer
##       "camera_position": [x,y],
##       "camera_zoom": float,
##       "grid_enabled": bool,
##       "active_strategy": "undirected" | "directed",
##       "is_weighted_mode": bool
##     }
##   }
extends RefCounted
class_name GraphDocumentIO

const FORMAT_VERSION := 2
const FILE_EXTENSION := "graphos"
const AUTOSAVE_PATH := "user://autosave.graphos"


## Write a complete document to disk. Returns true on success.
static func save(graph: Graph, camera: Camera2D, grid_enabled: bool, path: String) -> bool:
	var graph_data := GraphSerializer.to_dictionary(graph)
	var app_state := AppStateSerializer.to_dictionary(camera, grid_enabled)

	var doc := {
		"format_version": FORMAT_VERSION,
		"next_vertex_id": graph_data["next_vertex_id"],
		"vertices": graph_data["vertices"],
		"edges": graph_data["edges"],
		"app_state": app_state,
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GraphDocumentIO: cannot open '%s' for writing (error %d)." \
				% [path, FileAccess.get_open_error()])
		return false

	file.store_string(JSON.stringify(doc, "\t"))
	file.close()
	return true


## Load a document from disk.
## Returns { "graph_data": Dictionary, "app_state": Dictionary } on success,
## or an empty Dictionary on failure.  Callers should check is_empty() before use.
static func load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GraphDocumentIO: file is empty: %s" % path)
		return {}

	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GraphDocumentIO: invalid JSON root in '%s'." % path)
		return {}

	var ver := int(data.get("format_version", 0))
	if ver < 1 or ver > FORMAT_VERSION:
		push_error("GraphDocumentIO: unsupported format_version %d in '%s'." % [ver, path])
		return {}

	# Gracefully handle format_version 1 preset files that have no app_state.
	var raw_app_state = data.get("app_state", {})
	if typeof(raw_app_state) != TYPE_DICTIONARY:
		raw_app_state = {}

	return {
		"graph_data": data,
		"app_state": AppStateSerializer.from_dictionary(raw_app_state),
	}
