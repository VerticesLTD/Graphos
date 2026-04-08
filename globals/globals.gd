extends Node
# ------------
# Logging tags
# ------------
const INPT_TAG = "INPUT"
const SETUP_TAG = "SETUP"
const VIS_TAG = "VISUAIZER"
const MGR_TAG = "MANAGER"
const EVNT_TAG = "EVENT"
# ------------
# App states
# ------------
signal app_state_changed
## Selection buffer or edge link head changed — refresh contextual toolbar hints.
signal tool_hint_context_changed
signal algorithm_key_visuals_changed
## Emitted when the active edge strategy (directed/undirected) changes.
signal strategy_changed
## Emitted when weighted-mode toggles.
signal weighted_mode_changed
enum State {
	SELECTION,
	CREATE,
	PAN,
	EDGE,
	ALG,
	ERASER,
}
var current_state: State:
	set(value):
		current_state = value
		app_state_changed.emit()


## Pan and eraser own the pointer (hand / brush). Graph elements must not show hover rings or
## selection-driven glow from [AnimationManager] while these tools are active.
func graph_hover_highlights_disabled() -> bool:
	return current_state == State.PAN or current_state == State.ERASER


var algorithm_show_vertex_keys: bool = false:
	set(value):
		if algorithm_show_vertex_keys == value:
			return
		algorithm_show_vertex_keys = value
		algorithm_key_visuals_changed.emit()

## Set of vertex IDs participating in the currently running algorithm.
var algorithm_key_vertex_ids: Dictionary = {}:
	set(value):
		algorithm_key_vertex_ids = value
		algorithm_key_visuals_changed.emit()

# ------------
# Tool Modifiers (For CREATE state)
# ------------
## Independent modifiers that determine the type of edge being drawn.
var active_strategy: ConnectionStrategy = UndirectedStrategy.new():
	set(value):
		active_strategy = value
		strategy_changed.emit()
var is_weighted_mode: bool = false:
	set(value):
		is_weighted_mode = value
		weighted_mode_changed.emit()
# Tracks the state of a vertex's edges to prevent mixing.
enum WeightState { EMPTY, WEIGHTED, UNWEIGHTED, CORRUPTED }
# ------------
# Appearance
# ------------
const BUTTON_REGULAR_MODULATE = Color(0.25, 0.25, 0.28)
const BUTTON_REGULAR_SCALE = Vector2(1, 1)
const BUTTON_HIGHLIGHT_MODULATE = Color("4361ee")
const BUTTON_HIGHLIGHT_SCALE = Vector2(1.2, 1.2)
# Vertices
const VERTEX_RADIUS = 20.0
const VERTEX_COLOR = Color("1e1e2e")
# Vertex animations
const VERTEX_COLOR_CHAIN = Color("06d6a0")
const VERTEX_COLOR_CHAIN_HEAD = Color("f72585")
const VERTEX_HOVER_SCALE = 1.2
const VERTEX_HOVER_COLOR = Color("4361ee")
const VERTEX_TWEEN_TIME = 0.2
const SELECTION_BOUNDS_PADDING = 0.0
# Edges
const EDGE_COLOR = Color("495057")
const EDGE_WIDTH = 5.0
const EDGE_HOVER_COLOR = Color("4361ee")
const EDGE_HOVER_SCALE = 1.3
const EDGE_TWEEN_TIME = 0.2
const EDGE_FLOW_TWEEN_TIME = 0.08
# Panel / UI Theme
const PANEL_INK_COLOR   = Color("1e1e2e")  # primary dark text
const PANEL_DIM_COLOR   = Color("555577")  # dim/secondary text
const APP_ERROR_COLOR   = Color("ef233c")  # error red
# Selection rectangle
const SELECTION_BORDER_WIDTH: float = 2.0
const SELECTION_BORDER_COLOR: Color = Color("4da1a9")
const SELECTION_FILL_COLOR: Color = Color8(77, 161, 169, 30)
# ------------
# Input constants
# ------------
# How long (in seconds) until a click counts as a "Hold"
const HOLD_THRESHOLD = 0.10
# ------------
# how close to a edge to trigger get_edge_at in graphController
const EDGE_DISTANCE_THRESHOLD = 5
# ------------
# Drag state
# ------------
## This variable is accessed by the app's elements when in drag mode.
var is_mass_select: bool = false
var selection_rectangle: Rect2
# ------------
# Clipboard
# ------------
## Stores induced graph for copy paste
var clipboard_graph: Graph
# ------------
# IDENTIFIRES
# ------------
const NOT_FOUND = -1
# ------------
# Capacity and Limits
# ------------
const INF: float = 1e18
# ------------
# EDGE LINE EDIT
# ------------
var active_weight_editor: LineEdit = null

# ------------
# Mobile Layout
# ------------
func is_mobile_layout(viewport: Viewport) -> bool:
	var w := float(DisplayServer.window_get_size().x)
	var vp_w := viewport.get_visible_rect().size.x
	if w <= 0.0:
		w = vp_w
	else:
		w = minf(w, vp_w)
	if OS.has_feature("web"):
		var inner: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if inner != null:
			var iw := float(inner)
			if iw > 0.0:
				w = minf(w, iw)
	return w <= 768.0
