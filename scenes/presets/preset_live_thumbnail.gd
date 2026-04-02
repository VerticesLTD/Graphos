## Live preset preview: SubViewport + mini renderer (follows Globals vertex/edge colors).
extends Control
class_name PresetLiveThumbnail

@onready var _vp: SubViewport = $SubViewportContainer/SubViewport
@onready var _ren: PresetGraphMiniRenderer = $SubViewportContainer/SubViewport/MiniRenderer

var _pending_json_path: String = ""


func _ready() -> void:
	add_to_group("preset_live_thumbnails")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var svc: SubViewportContainer = $SubViewportContainer
	if svc:
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_pending_json()


## Call after instantiate() with path; actual load runs in _ready when @onready refs exist.
func configure(json_path: String) -> void:
	_pending_json_path = json_path
	if is_node_ready():
		_apply_pending_json()


func _apply_pending_json() -> void:
	if _pending_json_path.is_empty() or _ren == null or _vp == null:
		return
	_ren.set_graph_from_json_path(_pending_json_path)
	# SubViewport must repaint; WHEN_PARENT_VISIBLE can skip updates if timing is wrong during layout.
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	call_deferred("_maybe_relax_viewport_update")


func _maybe_relax_viewport_update() -> void:
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE


## Back-compat for any older callers.
func prepare_from_json_path(json_path: String) -> void:
	configure(json_path)


func refresh() -> void:
	if _ren:
		_ren.refresh()
