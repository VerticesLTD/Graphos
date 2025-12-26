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
# Vertex globals
# ------------
var vertex_id = 0
const VERTEX_RADIUS = 20.0

# ------------
# IDENTIFIRES
# ------------
const NOT_FOUND = -1
