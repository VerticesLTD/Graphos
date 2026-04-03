## Handles all web-sharing: reading/writing the URL hash, clipboard copy,
## and registering a hashchange listener so a pasted share-link loads live.
##
## Web-only: all JavaScriptBridge calls are guarded by OS.has_feature("web").
## On desktop this node is essentially a no-op.
##
## Scene order: ShareManager MUST appear before PersistenceManager in main.tscn
## so that _ready() here runs first and loaded_from_url is already set when
## PersistenceManager._ready() checks it.
extends Node
class_name ShareManager

## True when a share URL was successfully decoded and applied on startup.
## PersistenceManager reads this to skip loading the autosave.
var loaded_from_url: bool = false

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
# Startup URL loading
# ---------------------------------------------------------------------------

func _try_load_from_url() -> void:
	var fragment: String = JavaScriptBridge.eval("window.location.hash")
	if fragment.is_empty() or not ShareEncoder.is_share_fragment(fragment):
		return

	var result := ShareEncoder.from_url_fragment(fragment)
	if result.is_empty():
		push_warning("ShareManager: failed to decode share fragment.")
		return

	if _persistence_manager == null:
		push_warning("ShareManager: PersistenceManager not found — cannot apply shared graph.")
		return

	_persistence_manager.apply_document(result)
	loaded_from_url = true

	# Clear hash so reloads / bookmarks don't re-apply the same graph.
	JavaScriptBridge.eval(
		"history.replaceState(null,'',window.location.pathname+window.location.search)"
	)


func _register_hashchange_listener() -> void:
	_hashchange_callback = JavaScriptBridge.create_callback(_on_hashchange)
	JavaScriptBridge.get_interface("window").addEventListener("hashchange", _hashchange_callback)


func _on_hashchange(_args: Array) -> void:
	var fragment: String = JavaScriptBridge.eval("window.location.hash")
	if fragment.is_empty() or not ShareEncoder.is_share_fragment(fragment):
		return
	var result := ShareEncoder.from_url_fragment(fragment)
	if result.is_empty():
		return
	if _persistence_manager:
		_persistence_manager.apply_document(result)
		_persistence_manager.suspend_autosave()
	JavaScriptBridge.eval(
		"history.replaceState(null,'',window.location.pathname+window.location.search)"
	)


# ---------------------------------------------------------------------------
# URL generation & clipboard copy (called by SharePanel)
# ---------------------------------------------------------------------------

## Generate the full shareable URL for the current graph state.
## Returns "" on desktop or on error.
func get_share_url(graph: Graph, camera: Camera2D, grid_enabled: bool) -> String:
	if not OS.has_feature("web"):
		return ""
	if not graph or not camera:
		return ""
	var fragment := ShareEncoder.to_url_fragment(graph, camera, grid_enabled)
	var base_url: String = JavaScriptBridge.eval(
		"window.location.origin+window.location.pathname"
	)
	return base_url + fragment


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
