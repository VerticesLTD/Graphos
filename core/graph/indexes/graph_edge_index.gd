## Centralized edge lookup tables for Graph.
##
## Two indexes are maintained in lockstep:
##   _edge_by_key           — O(1) "does edge A→B exist?" (used by has_edge / get_edge)
##   _incoming_by_vertex_id — O(1) "what points at V?" (used by get_incoming_edges)
##
## Both are updated by the connection strategies via Graph._on_edge_added/removed.
## Graph itself never touches the raw dictionaries directly.
class_name GraphEdgeIndex
extends RefCounted

var _incoming_by_vertex_id: Dictionary = {} ## dst_id -> Array[Edge]
var _edge_by_key: Dictionary = {}           ## "src_id:dst_id" -> Edge


func clear() -> void:
	_incoming_by_vertex_id.clear()
	_edge_by_key.clear()


func register_vertex(vertex_id: int) -> void:
	_incoming_by_vertex_id[vertex_id] = []


func unregister_vertex(vertex_id: int) -> void:
	_incoming_by_vertex_id.erase(vertex_id)


func on_edge_added(edge: Edge) -> void:
	if edge == null or edge.src == null or edge.dst == null:
		return
	var dst_id := edge.dst.id
	if not _incoming_by_vertex_id.has(dst_id):
		_incoming_by_vertex_id[dst_id] = []
	(_incoming_by_vertex_id[dst_id] as Array).append(edge)
	_edge_by_key[_edge_key(edge.src.id, edge.dst.id)] = edge


func on_edge_removed(edge: Edge) -> void:
	if edge == null or edge.src == null or edge.dst == null:
		return
	var dst_id := edge.dst.id
	var incoming: Array = _incoming_by_vertex_id.get(dst_id, [])
	if incoming.is_empty():
		return
	incoming.erase(edge)
	_incoming_by_vertex_id[dst_id] = incoming
	_edge_by_key.erase(_edge_key(edge.src.id, edge.dst.id))


func get_edge(src_id: int, dst_id: int) -> Edge:
	return _edge_by_key.get(_edge_key(src_id, dst_id)) as Edge


func has_edge(src_id: int, dst_id: int) -> bool:
	return _edge_by_key.has(_edge_key(src_id, dst_id))


func get_incoming_edges(target_id: int) -> Array[Edge]:
	var cached: Array = _incoming_by_vertex_id.get(target_id, [])
	var result: Array[Edge] = []
	for e in cached:
		if e != null:
			result.append(e as Edge)
	return result


func _edge_key(src_id: int, dst_id: int) -> String:
	return "%d:%d" % [src_id, dst_id]
