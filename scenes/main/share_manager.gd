## Handles all web-sharing: reading/writing the URL, clipboard copy,
## and registering a hashchange listener so a pasted share-link loads live.
##
## Web-only: all JavaScriptBridge calls are guarded by OS.has_feature("web").
## On desktop this node is essentially a no-op.
##
## Scene order: ShareManager MUST appear before PersistenceManager in main.tscn
## so that _ready() here runs first and loaded_from_url / pending_conflict are
## already set when PersistenceManager._ready() checks them.
##
## Share URL format:
##   app.com/?graphId=<id>#json=<compressed-graph>   (sharing with someone new)
##   app.com/?graphId=<id>                            (bookmark / reload)
##
## After a successful load from a full share URL the hash is stripped, leaving
## only "?graphId=<id>" as a clean, bookmarkable reference.
extends Node
class_name ShareManager

## True when a share URL was successfully decoded and applied on startup.
## PersistenceManager reads this to skip loading from GraphStore.
var loaded_from_url: bool = false

## Non-empty when the incoming share URL targets a graph_id the user already
## has locally.  PersistenceManager resolves this after its own _ready().
## Shape: { "graph_id": String, "shared_doc": Dictionary }
var pending_conflict: Dictionary = {}

## Keeps the JavaScriptObject alive so the GC does not destroy the callback.
var _hashchange_callback: JavaScriptObject

@onready var _persistence_manager: PersistenceManager = (
	get_node_or_null("../PersistenceManager") as PersistenceManager
)


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_try_load_from_url()
	_register_hashchange_listener()


# ---------------------------------------------------------------------------
# Startup URL handling
# ---------------------------------------------------------------------------

func _try_load_from_url() -> void:
	var fragment: String  = str(JavaScriptBridge.eval("window.location.hash"))
	var url_graph_id: String = str(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('graphId')||''"
	))

	var has_fragment  := ShareEncoder.is_share_fragment(fragment)
	var has_graph_id  := not url_graph_id.is_empty()

	# Case: bookmark / reload — just an ID, no graph data in the URL.
	if has_graph_id and not has_fragment:
		if GraphStore.exists(url_graph_id) and _persistence_manager != null:
			var result := GraphStore.load_graph(url_graph_id)
			if not result.is_empty():
				_persistence_manager.apply_document(result)
				_persistence_manager.set_active_graph_id(url_graph_id)
				loaded_from_url = true
		# If the graph no longer exists locally, fall through to normal startup.
		return

	# Case: incoming share link — graph data embedded in the fragment.
	if has_fragment:
		var result := ShareEncoder.from_url_fragment(fragment)
		if result.is_empty():
			push_warning("ShareManager: failed to decode share fragment.")
			return

		# Determine the stable ID: prefer URL query param, then embedded, then generate.
		var decoded_id: String = result.get("graph_id", "")
		var effective_id := url_graph_id if not url_graph_id.is_empty() \
				else (decoded_id if not decoded_id.is_empty() \
				else GraphIdUtil.generate())

		# Stamp the effective ID into the result so apply_document() can pick it up.
		result["graph_id"] = effective_id

		if GraphStore.exists(effective_id):
			# The user already has a local copy — defer conflict resolution.
			pending_conflict = {"graph_id": effective_id, "shared_doc": result}
			# Keep ?graphId= in the URL but clear the hash right away so
			# reloads do not re-trigger the conflict dialog.
			_set_url_graph_id(effective_id, clear_hash: true)
			return

		# No conflict: save the shared graph locally and make it active.
		_persist_result(effective_id, result)
		if _persistence_manager != null:
			_persistence_manager.apply_document(result)
			_persistence_manager.set_active_graph_id(effective_id)
		loaded_from_url = true
		_set_url_graph_id(effective_id, clear_hash: true)


# ---------------------------------------------------------------------------
# hashchange listener (pasting a new share link while the app is open)
# ---------------------------------------------------------------------------

func _register_hashchange_listener() -> void:
	_hashchange_callback = JavaScriptBridge.create_callback(_on_hashchange)
	JavaScriptBridge.get_interface("window").addEventListener("hashchange", _hashchange_callback)


func _on_hashchange(_args: Array) -> void:
	var fragment: String = str(JavaScriptBridge.eval("window.location.hash"))
	if not ShareEncoder.is_share_fragment(fragment):
		return

	var result := ShareEncoder.from_url_fragment(fragment)
	if result.is_empty():
		return

	# For live hash-changes we always apply directly (no conflict dialog;
	# the user explicitly pasted the link).
	var decoded_id: String = result.get("graph_id", "")
	if decoded_id.is_empty():
		decoded_id = GraphIdUtil.generate()
	result["graph_id"] = decoded_id

	_persist_result(decoded_id, result)
	if _persistence_manager:
		_persistence_manager.apply_document(result)
		_persistence_manager.set_active_graph_id(decoded_id)
	_set_url_graph_id(decoded_id, clear_hash: true)


# ---------------------------------------------------------------------------
# URL management helpers
# ---------------------------------------------------------------------------

## Update the browser URL to show ?graphId=<id>, optionally clearing the hash.
func _set_url_graph_id(graph_id: String, clear_hash: bool = false) -> void:
	if not OS.has_feature("web"):
		return
	var search := ("?graphId=%s" % graph_id) if not graph_id.is_empty() else ""
	var hash   := "" if clear_hash else str(JavaScriptBridge.eval("window.location.hash"))
	JavaScriptBridge.eval(
		"history.replaceState(null,'',window.location.pathname+'%s%s')" % [search, hash]
	)


## Update the browser URL whenever the active graph changes.
## Called by PersistenceManager after any graph switch.
func sync_url_to_graph_id(graph_id: String) -> void:
	_set_url_graph_id(graph_id)


# ---------------------------------------------------------------------------
# Share URL generation
# ---------------------------------------------------------------------------

## Generate the full shareable URL for the current graph state.
## Includes ?graphId=<id> and the #json= fragment.
## Returns "" on desktop or on error.
func get_share_url(graph: Graph, camera: Camera2D, grid_enabled: bool,
		graph_id: String = "") -> String:
	if not OS.has_feature("web"):
		return ""
	if not graph or not camera:
		return ""
	var fragment := ShareEncoder.to_url_fragment(graph, camera, grid_enabled, graph_id)
	var base_url := str(JavaScriptBridge.eval(
		"window.location.origin+window.location.pathname"
	))
	var search := ("?graphId=%s" % graph_id) if not graph_id.is_empty() else ""
	return base_url + search + fragment


# ---------------------------------------------------------------------------
# Clipboard
# ---------------------------------------------------------------------------

## Copy text to the clipboard using the best available browser API.
func copy_to_clipboard(text: String) -> void:
	if not OS.has_feature("web"):
		return
	var safe := text.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("""
(function(){
	var t='%s';
	if(navigator.clipboard&&window.isSecureContext){
		navigator.clipboard.writeText(t).catch(function(){_fb(t)});
	}else{_fb(t);}
	function _fb(s){
		var el=document.createElement('textarea');
		el.value=s;
		el.style.position='fixed';
		el.style.opacity='0';
		document.body.appendChild(el);
		el.focus();el.select();
		try{document.execCommand('copy');}catch(e){}
		document.body.removeChild(el);
	}
})()
""" % [safe])


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Build a raw document from a decoded result and save it to GraphStore.
func _persist_result(graph_id: String, result: Dictionary) -> void:
	var raw_doc: Dictionary = result["graph_data"].duplicate(true)
	raw_doc["graph_id"] = graph_id
	GraphStore.save(graph_id, raw_doc)
	GraphStore.set_last_opened_id(graph_id)
