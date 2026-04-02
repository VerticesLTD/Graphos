## Shared arrow math so ghost previews match UIEdgeView directed edges.
class_name EdgeArrowGeometry

static func get_arrow_dimensions(edge_distance: float, current_line_width: float) -> Vector2:
	var available_span: float = maxf(edge_distance - (Globals.VERTEX_RADIUS * 2.0), 0.0)
	var preferred_length: float = current_line_width * 5.0
	var arrow_length: float = clampf(preferred_length, 8.0, maxf(8.0, available_span * 0.45))
	var arrow_width: float = clampf(current_line_width * 2.2, 4.0, maxf(4.0, arrow_length * 0.5))
	return Vector2(arrow_length, arrow_width)


static func build_arrow_polygon(arrow_length: float, arrow_width: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(-arrow_length, -arrow_width),
		Vector2(-arrow_length * 0.75, 0.0),
		Vector2(-arrow_length, arrow_width),
	])
