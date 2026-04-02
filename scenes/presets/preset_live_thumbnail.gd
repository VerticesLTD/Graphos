## Live preset preview: SubViewport + mini renderer (follows Globals vertex/edge colors).
extends Control
class_name PresetLiveThumbnail

@onready var _vp: SubViewport = $SubViewportContainer/SubViewport
@onready var _ren: PresetGraphMiniRenderer = $SubViewportContainer/SubViewport/MiniRenderer


func _ready() -> void:
	add_to_group("preset_live_thumbnails")
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE


func prepare_from_json_path(json_path: String) -> void:
	if _ren:
		_ren.set_graph_from_json_path(json_path)
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE


func refresh() -> void:
	if _ren:
		_ren.refresh()
