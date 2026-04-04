## Persists first-time welcome dismissal: localStorage on web, ConfigFile on desktop.
extends RefCounted
class_name FirstVisitStore

const LOCAL_STORAGE_KEY := "has_seen_graphos"

const _CONFIG_PATH := "user://graphos_app.cfg"
const _CONFIG_SECTION := "welcome"
const _CONFIG_KEY := "has_seen_graphos"


static func has_seen_welcome() -> bool:
	if OS.has_feature("web"):
		return _web_has_flag()
	var cfg := ConfigFile.new()
	if cfg.load(_CONFIG_PATH) != OK:
		return false
	return bool(cfg.get_value(_CONFIG_SECTION, _CONFIG_KEY, false))


static func mark_welcome_seen() -> void:
	if OS.has_feature("web"):
		_web_set_flag()
		return
	var cfg := ConfigFile.new()
	cfg.load(_CONFIG_PATH)
	cfg.set_value(_CONFIG_SECTION, _CONFIG_KEY, true)
	cfg.save(_CONFIG_PATH)


static func _web_has_flag() -> bool:
	var v: Variant = JavaScriptBridge.eval(
		'(function(){ try { return localStorage.getItem("%s"); } catch(e) { return null; } })()'
		% LOCAL_STORAGE_KEY
	)
	if v == null:
		return false
	var s := str(v).strip_edges()
	return s == "1" or s.to_lower() == "true"


static func _web_set_flag() -> void:
	JavaScriptBridge.eval(
		'(function(){ try { localStorage.setItem("%s", "1"); } catch(e) {} })()' % LOCAL_STORAGE_KEY
	)
