## Spatial hash that speeds up "which vertex is under the cursor?" checks.
##
## The world is divided into square cells of _cell_size units. Each vertex
## lives in exactly one cell. When picking, we check the 3×3 neighbourhood
## of the cursor cell so we never miss a vertex that straddles a cell boundary.
##
## Time complexity:
##   track / untrack  — O(1) average
##   on_vertex_moved  — O(1) when the cell doesn't change (the common case)
##   get_candidates   — O(1) — at most 9 cells × a tiny bucket each
class_name GraphVertexSpatialIndex
extends RefCounted

var _cell_size: float
var _grid: Dictionary = {}       ## "cx:cy" -> Array[int]   (the spatial buckets)
var _cell_by_id: Dictionary = {} ## vertex_id -> "cx:cy"    (reverse map for fast moves)


func _init(cell_size: float) -> void:
	_cell_size = cell_size


func clear() -> void:
	_grid.clear()
	_cell_by_id.clear()


## Register a vertex at the given world position.
func track_vertex(vertex_id: int, pos: Vector2) -> void:
	_insert(vertex_id, _cell_key_from_pos(pos))


## Remove a vertex from the index entirely.
func untrack_vertex(vertex_id: int) -> void:
	var cell := _cell_by_id.get(vertex_id, "") as String
	if cell.is_empty():
		return
	_remove_from_bucket(vertex_id, cell)
	_cell_by_id.erase(vertex_id)


## Call this whenever a vertex moves — keeps the bucket membership in sync.
func on_vertex_moved(vertex_id: int, old_pos: Vector2, new_pos: Vector2) -> void:
	var from_cell := _cell_key_from_pos(old_pos)
	var to_cell := _cell_key_from_pos(new_pos)
	if from_cell == to_cell:
		return  # Same cell, nothing to update.
	_remove_from_bucket(vertex_id, from_cell)
	_insert(vertex_id, to_cell)


## Returns all vertex IDs that could possibly contain pos (3×3 neighbourhood).
## The caller still needs to do a radius check on each candidate.
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
