## Serializes and deserializes app-level view state: camera, grid, strategy, weighted mode.
##
## Pure data layer — no Node lifecycle, no I/O, safe to call from anywhere.
## Fills in safe defaults for every missing key so old documents load cleanly.
##
## Output shape:
##   { "camera_position": [x,y], "camera_zoom": float,
##     "grid_enabled": bool, "active_strategy": str, "is_weighted_mode": bool }
extends RefCounted
class_name AppStateSerializer


## Capture current view state into a plain Dictionary.
static func to_dictionary(camera: Camera2D, grid_enabled: bool) -> Dictionary:
	return {
		"camera_position": [camera.position.x, camera.position.y],
		"camera_zoom": camera.zoom.x,
		"grid_enabled": grid_enabled,
		"active_strategy": "directed" if Globals.active_strategy is DirectedStrategy else "undirected",
		"is_weighted_mode": Globals.is_weighted_mode,
	}


## Parse a raw Dictionary (from JSON) into typed fields, filling in defaults for
## any missing keys.  Safe to call on format_version 1 documents that have no app_state.
static func from_dictionary(data: Dictionary) -> Dictionary:
	var pos_raw = data.get("camera_position", [0.0, 0.0])
	var cam_pos := Vector2.ZERO
	if typeof(pos_raw) == TYPE_ARRAY and pos_raw.size() >= 2:
		cam_pos = Vector2(float(pos_raw[0]), float(pos_raw[1]))

	return {
		"camera_position": cam_pos,
		"camera_zoom": float(data.get("camera_zoom", 1.0)),
		"grid_enabled": bool(data.get("grid_enabled", true)),
		"active_strategy": str(data.get("active_strategy", "undirected")),
		"is_weighted_mode": bool(data.get("is_weighted_mode", false)),
	}
