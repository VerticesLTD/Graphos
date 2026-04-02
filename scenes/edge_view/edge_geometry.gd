extends RefCounted
class_name EdgeGeometry

## Shared math helpers for edge rendering and hit-testing.
## Keeping this logic out of UIEdgeView makes the view easier to maintain.

static func should_draw_bidirectional_curve(edge_data: Edge, graph: Graph) -> bool:
	if not edge_data or not (edge_data.strategy is DirectedStrategy):
		return false
	if graph == null:
		return false
	return graph.has_edge(edge_data.dst.id, edge_data.src.id)

static func get_linear_visual_start_end(pos1: Vector2, pos2: Vector2, vertex_radius: float) -> Array[Vector2]:
	var direction = pos1.direction_to(pos2)
	var seg_start = pos1 + (direction * vertex_radius)
	var seg_end = pos2 - (direction * vertex_radius)
	var out: Array[Vector2] = [seg_start, seg_end]
	return out

static func get_bidirectional_control_point(
	edge_data: Edge,
	start: Vector2,
	finish: Vector2,
	curve_factor: float,
	curve_min: float,
	curve_max: float
) -> Vector2:
	var lower_v = edge_data.src
	var upper_v = edge_data.dst
	var is_src_lower = edge_data.src.id < edge_data.dst.id
	if not is_src_lower:
		lower_v = edge_data.dst
		upper_v = edge_data.src

	# Stable pair orientation guarantees mirrored arcs for A->B and B->A.
	var pair_dir = lower_v.pos.direction_to(upper_v.pos)
	var normal = Vector2(-pair_dir.y, pair_dir.x)
	var bend_sign = 1.0 if is_src_lower else -1.0
	var distance = lower_v.pos.distance_to(upper_v.pos)
	var bend = clamp(distance * curve_factor, curve_min, curve_max)
	return start.lerp(finish, 0.5) + (normal * bend * bend_sign)

static func quadratic_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var inv = 1.0 - t
	return (inv * inv * p0) + (2.0 * inv * t * p1) + (t * t * p2)

static func quadratic_tangent(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)

static func sample_quadratic(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	start_t: float,
	end_t: float,
	steps: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_steps = maxi(steps, 2)
	for i in range(safe_steps):
		var alpha = float(i) / float(safe_steps - 1)
		var t = lerpf(start_t, end_t, alpha)
		points.append(quadratic_point(p0, p1, p2, t).round())
	return points

static func estimate_polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return length

static func is_point_near_polyline(mouse_world_pos: Vector2, points: PackedVector2Array, threshold: float) -> bool:
	if points.size() < 2:
		return false
	var threshold_sq = threshold * threshold
	for i in range(1, points.size()):
		var closest = Geometry2D.get_closest_point_to_segment(mouse_world_pos, points[i - 1], points[i])
		var d2 = mouse_world_pos.distance_squared_to(closest)
		if d2 <= threshold_sq:
			return true
	return false
