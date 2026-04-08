extends Label

## Mirrors the breakpoint used by tool_bar.gd so the hint hides on mobile
## (the toolbar moves to the bottom on narrow screens, leaving no good spot for text).
const MOBILE_VIEWPORT_MAX_WIDTH := 768.0

var _graph_controller: GraphController


func _ready() -> void:
	_graph_controller = get_node("../../GraphController") as GraphController
	Globals.app_state_changed.connect(_update_text)
	Globals.tool_hint_context_changed.connect(_update_text)
	get_window().size_changed.connect(_update_visibility)
	_update_text()
	_update_visibility()


func _update_text() -> void:
	if _graph_controller == null:
		return
	match Globals.current_state:
		Globals.State.SELECTION:
			if _graph_controller.selection_buffer.is_empty():
				text = "Click or drag to select  ·  To move canvas, hold scroll wheel or switch to Pan mode"
			else:
				text = "Right-click selection for options"
		Globals.State.CREATE:
			text = "Click to add vertex  ·  Hold Ctrl + click two vertices to connect"
		Globals.State.PAN:
			text = "Drag to pan  ·  Scroll to zoom"
		Globals.State.EDGE:
			if _graph_controller.link_head == Globals.NOT_FOUND:
				text = "Click a vertex to start connection"
			else:
				text = "Click second vertex to connect  ·  Click same to cancel"
		Globals.State.ERASER:
			text = "Drag over items to delete  ·  Escape to cancel"
		_:
			text = ""


func _update_visibility() -> void:
	var w := float(DisplayServer.window_get_size().x)
	if OS.has_feature("web"):
		var inner: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if inner != null and float(inner) > 0.0:
			w = minf(w, float(inner))
	visible = w > MOBILE_VIEWPORT_MAX_WIDTH
