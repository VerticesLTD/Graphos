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
enum State {
	DRAG,
	VERTEX,
	ALG,
	ERASER,
}
var current_state: State

# ------------
# Appearance
# ------------
const BUTTON_REGULAR_MODULATE = Color(1, 1, 1)
const BUTTON_REGULAR_SCALE = Vector2(1,1)
const BUTTON_HIGHLIGHT_MODULATE = Color(1.2, 1.2, 1.2)
const BUTTON_HIGHLIGHT_SCALE = Vector2(1.1,1.1)

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
# Vertex globals
# ------------
var vertex_id = 0
const VERTEX_RADIUS = 20.0

# ------------
# IDENTIFIRES
# ------------
const NOT_FOUND = -1
