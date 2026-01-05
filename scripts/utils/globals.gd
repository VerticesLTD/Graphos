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
const BUTTON_REGULAR_SCALE = Vector2(1,1)
const BUTTON_HIGHLIGHT_MODULATE = Color(1.2, 1.2, 1.2)
const BUTTON_HIGHLIGHT_SCALE = Vector2(1.1,1.1)

# Vertices
const VERTEX_RADIUS = 20.0
const VERTEX_COLOR = Color("1282A2")

# Edges
const EDGE_COLOR = Color("FEFCFB")
const EDGE_WIDTH = 5.0

# ------------
# Input constants
# ------------
# How long (in seconds) until a click counts as a "Hold"
const HOLD_THRESHOLD = 0.10

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
