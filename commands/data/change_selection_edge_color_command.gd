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
	if not bypass_lock:
		for e in _edges:
			if e.is_algorithm_locked:
				Notify.show_error("Cannot recolor: the selection contains an edge that is part of a running algorithm.")
				return
	for e in _edges:
		e.color = _new_color

func undo() -> void:
	for i in range(_edges.size()):
		_edges[i].color = _old_colors[i]
