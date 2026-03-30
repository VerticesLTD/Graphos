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

enum State {
	SELECTION,
	CREATE,
	ALG,
	ERASER,
}
var current_state: State:
	set(value):
		current_state = value
		app_state_changed.emit()

# ------------
# Appearance
# ------------
const BUTTON_REGULAR_MODULATE = Color(1, 1, 1)
const BUTTON_REGULAR_SCALE = Vector2(1, 1)
const BUTTON_HIGHLIGHT_MODULATE = Color("66b2ff")
const BUTTON_HIGHLIGHT_SCALE = Vector2(1.2, 1.2)

# Vertices
const VERTEX_RADIUS = 20.0
const VERTEX_COLOR = Color("1282A2")

# Vertex animations
const VERTEX_COLOR_CHAIN = Color.GREEN_YELLOW
const VERTEX_COLOR_CHAIN_HEAD = Color.YELLOW
const VERTEX_HOVER_SCALE = 1.2
const VERTEX_HOVER_COLOR = Color("4DB8D8")
const VERTEX_TWEEN_TIME = 0.2

# Edges
const EDGE_COLOR = Color("FEFCFB")
const EDGE_WIDTH = 5.0
const EDGE_HOVER_COLOR = Color("FFE66D")
const EDGE_HOVER_SCALE = 1.3
const EDGE_TWEEN_TIME = 0.2
const EDGE_FLOW_TWEEN_TIME = 0.08


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
var clipboard_graph: UndirectedGraph

# ------------
# IDENTIFIRES
# ------------
const NOT_FOUND = -1

# ------------
# Capacity and Limits
# ------------
const MAX_VERTICES: int = 500

# ------------
# EDGE LINE EDIT
# ------------
var active_weight_editor: LineEdit = null
