## Command to recolor multiple selected edges in one undo step.
class_name ChangeSelectionEdgeColorCommand
extends Command

var _edges: Array[Edge] = []
var _old_colors: Array[Color] = []
var _new_color: Color

func _init(edges: Array[Edge], target_color: Color):
	_new_color = target_color
	for e in edges:
		if e:
			_edges.append(e)
			_old_colors.append(e.color)

func execute() -> void:
	if _any_edge_locked(_edges, "recolor"): return
	for e in _edges:
		e.color = _new_color

func undo() -> void:
	for i in range(_edges.size()):
		_edges[i].color = _old_colors[i]
