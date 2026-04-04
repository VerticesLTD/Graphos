extends Label

## Mirrors the breakpoint used by tool_bar.gd so the hint hides on mobile
## (the toolbar moves to the bottom on narrow screens, leaving no good spot for text).
const MOBILE_VIEWPORT_MAX_WIDTH := 768.0

func _ready() -> void:
	Globals.app_state_changed.connect(_update_text)
	get_window().size_changed.connect(_update_visibility)
	_update_text()
	_update_visibility()


func _update_text() -> void:
	match Globals.current_state:
		Globals.State.SELECTION:
			text = "Click to select  ·  Drag to multi-select  ·  Right-click selection to run algorithms"
		Globals.State.CREATE:
			text = "Click to place a vertex  ·  Hold Ctrl + click two vertices to connect"
		Globals.State.PAN:
			text = "Drag to pan  ·  Scroll to zoom"
		Globals.State.EDGE:
			text = "Click a vertex to start  ·  Click another to connect  ·  Click the same to cancel  ·  Right-click an edge to remove"
		Globals.State.ERASER:
			text = "Click and drag over vertices or edges to erase  ·  Release to confirm  ·  Escape to cancel"
		_:
			text = ""


func _update_visibility() -> void:
	var w := float(DisplayServer.window_get_size().x)
	if OS.has_feature("web"):
		var inner: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if inner != null and float(inner) > 0.0:
			w = minf(w, float(inner))
	visible = w > MOBILE_VIEWPORT_MAX_WIDTH
