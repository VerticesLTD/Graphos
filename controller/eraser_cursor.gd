extends RefCounted

const _CURSOR_SVG := preload("res://assets/icons/eraser_cursor_circle.svg")

static var _cached: Image
static var _hotspot := Vector2(16, 16)


static func set_enabled(on: bool) -> void:
	if on:
		var img := _image()
		if img.is_empty():
			return
		DisplayServer.cursor_set_custom_image(img, DisplayServer.CURSOR_ARROW, _hotspot)
	else:
		DisplayServer.cursor_set_custom_image(null, DisplayServer.CURSOR_ARROW, Vector2())
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


static func _image() -> Image:
	if _cached != null and not _cached.is_empty():
		return _cached
	var tex: Texture2D = _CURSOR_SVG
	if tex == null:
		return Image.new()
	var raw := tex.get_image()
	if raw == null or raw.is_empty():
		return Image.new()
	_cached = raw.duplicate()
	_hotspot = Vector2(_cached.get_width(), _cached.get_height()) * 0.5
	return _cached
