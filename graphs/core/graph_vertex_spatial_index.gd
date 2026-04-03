## Lightweight spatial hash for fast vertex hit-testing.
class_name GraphVertexSpatialIndex
extends RefCounted

var _cell_size: float
var _grid: Dictionary = {}       ## "cx:cy" -> Array[int]
var _cell_by_id: Dictionary = {} ## vertex id -> "cx:cy"


func _init(cell_size: float) -> void:
	_cell_size = cell_size


func clear() -> void:
	_grid.clear()
	_cell_by_id.clear()


func track_vertex(vertex_id: int, pos: Vector2) -> void:
	_insert(vertex_id, _cell_key_from_pos(pos))


func untrack_vertex(vertex_id: int) -> void:
	var cell := _cell_by_id.get(vertex_id, "") as String
	if cell.is_empty():
		return
	_remove_from_bucket(vertex_id, cell)
	_cell_by_id.erase(vertex_id)


func on_vertex_moved(vertex_id: int, old_pos: Vector2, new_pos: Vector2) -> void:
	var from_cell := _cell_key_from_pos(old_pos)
	var to_cell := _cell_key_from_pos(new_pos)
	if from_cell == to_cell:
		return
	_remove_from_bucket(vertex_id, from_cell)
	_insert(vertex_id, to_cell)


func get_candidate_ids(pos: Vector2) -> Array:
	var out: Array = []
	var base := _cell_coord(pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var key := _cell_key(base.x + dx, base.y + dy)
			var ids: Array = _grid.get(key, [])
			for id in ids:
				out.append(id)
	return out


func _insert(vertex_id: int, cell: String) -> void:
	var bucket: Array = _grid.get(cell, [])
	bucket.append(vertex_id)
	_grid[cell] = bucket
	_cell_by_id[vertex_id] = cell


func _remove_from_bucket(vertex_id: int, cell: String) -> void:
	var bucket: Array = _grid.get(cell, [])
	if bucket.is_empty():
		return
	bucket.erase(vertex_id)
	if bucket.is_empty():
		_grid.erase(cell)
	else:
		_grid[cell] = bucket


func _cell_key_from_pos(pos: Vector2) -> String:
	var c := _cell_coord(pos)
	return _cell_key(c.x, c.y)


func _cell_coord(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / _cell_size)),
		int(floor(pos.y / _cell_size))
	)


func _cell_key(cx: int, cy: int) -> String:
	return "%d:%d" % [cx, cy]
