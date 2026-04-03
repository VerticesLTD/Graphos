## Command that transforms one or more edges in one undo step.
## Supports weight mode toggles and direction changes.
class_name TransformEdgesCommand
extends Command

enum WeightMode {
	KEEP,
	MAKE_WEIGHTED,
	MAKE_UNWEIGHTED,
}

enum DirectionMode {
	KEEP,
	DIRECTED_L_TO_R,
	DIRECTED_R_TO_L,
	BIDIRECTIONAL,
	UNDIRECTED,
}

var _before: Array[Dictionary] = []
var _after: Array[Dictionary] = []
var _pair_keys: Dictionary = {}
var _weight_mode: WeightMode = WeightMode.KEEP
var _direction_mode: DirectionMode = DirectionMode.KEEP


func _init(
	_graph: Graph,
	edges: Array[Edge],
	weight_mode: WeightMode = WeightMode.KEEP,
	direction_mode: DirectionMode = DirectionMode.KEEP
) -> void:
	super(_graph)
	_weight_mode = weight_mode
	_direction_mode = direction_mode
	_before = _unique_snapshots(edges)
	_after = _compute_after(_before)
	_collect_pair_keys(_before)
	_collect_pair_keys(_after)


func execute() -> void:
	_apply_state(_after)


func undo() -> void:
	_apply_state(_before)


func _apply_state(state: Array[Dictionary]) -> void:
	_delete_existing_edges_for_pairs()
	for snap in state:
		_add_snapshot_edge(snap)


func _delete_existing_edges_for_pairs() -> void:
	for key in _pair_keys.keys():
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() != 2:
			continue
		var a := int(parts[0])
		var b := int(parts[1])

		while graph.has_edge(a, b):
			graph.delete_edge(a, b)
		while graph.has_edge(b, a):
			graph.delete_edge(b, a)


func _add_snapshot_edge(snap: Dictionary) -> void:
	var src_id: int = snap["src_id"]
	var dst_id: int = snap["dst_id"]
	var weight: float = snap["weight"]
	var is_weighted: bool = snap["is_weighted"]
	var color: Color = snap["color"]
	var strategy: ConnectionStrategy
	if snap["is_directed"]:
		strategy = DirectedStrategy.new()
	else:
		strategy = UndirectedStrategy.new()

	graph.add_edge(src_id, dst_id, weight, strategy, is_weighted, true)

	var src_v := graph.get_vertex(src_id)
	var dst_v := graph.get_vertex(dst_id)
	if src_v == null or dst_v == null:
		return

	var e1: Edge = graph.get_edge(src_v, dst_v)
	if e1:
		e1.color = color
	var e2: Edge = graph.get_edge(dst_v, src_v)
	if e2:
		e2.color = color


func _compute_after(before: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for snap in before:
		var transformed := _apply_weight_mode_to_snapshot(snap)
		match _direction_mode:
			DirectionMode.KEEP:
				out.append(transformed)
			DirectionMode.DIRECTED_L_TO_R:
				out.append(_snapshot_with_direction(transformed, true, false))
			DirectionMode.DIRECTED_R_TO_L:
				out.append(_snapshot_with_direction(transformed, true, true))
			DirectionMode.BIDIRECTIONAL:
				out.append(_snapshot_with_direction(transformed, true, false))
				out.append(_snapshot_with_direction(transformed, true, true))
			DirectionMode.UNDIRECTED:
				out.append(_snapshot_with_direction(transformed, false, false))
	return out


func _apply_weight_mode_to_snapshot(snap: Dictionary) -> Dictionary:
	var updated: Dictionary = snap.duplicate()
	match _weight_mode:
		WeightMode.MAKE_WEIGHTED:
			updated["is_weighted"] = true
			if not bool(snap["is_weighted"]):
				updated["weight"] = 1.0
		WeightMode.MAKE_UNWEIGHTED:
			updated["is_weighted"] = false
		_:
			pass
	return updated


func _snapshot_with_direction(snap: Dictionary, directed: bool, reverse: bool) -> Dictionary:
	var updated: Dictionary = snap.duplicate()
	updated["is_directed"] = directed
	if reverse:
		updated["src_id"] = snap["dst_id"]
		updated["dst_id"] = snap["src_id"]
	return updated


func _collect_pair_keys(snaps: Array[Dictionary]) -> void:
	for snap in snaps:
		var a := mini(int(snap["src_id"]), int(snap["dst_id"]))
		var b := maxi(int(snap["src_id"]), int(snap["dst_id"]))
		_pair_keys["%d:%d" % [a, b]] = true


func _unique_snapshots(edges: Array[Edge]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}

	for edge in edges:
		if edge == null:
			continue

		var key := ""
		if edge.strategy is UndirectedStrategy:
			var a := mini(edge.src.id, edge.dst.id)
			var b := maxi(edge.src.id, edge.dst.id)
			key = "U:%d:%d" % [a, b]
		else:
			key = "D:%d:%d" % [edge.src.id, edge.dst.id]

		if seen.has(key):
			continue
		seen[key] = true

		out.append({
			"src_id": edge.src.id,
			"dst_id": edge.dst.id,
			"weight": edge.weight,
			"is_weighted": edge.is_weighted,
			"is_directed": edge.strategy is DirectedStrategy,
			"color": edge.color,
		})

	return out
