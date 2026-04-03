## Command to recolor multiple selected vertices in one undo step.
class_name ChangeSelectionVertexColorCommand
extends Command

var _vertices: Array[Vertex] = []
var _old_colors: Array[Color] = []
var _new_color: Color

func _init(vertices: Array[Vertex], target_color: Color):
	_new_color = target_color
	for v in vertices:
		if v:
			_vertices.append(v)
			_old_colors.append(v.color)

func execute() -> void:
	if _any_vertex_locked(_vertices, "recolor"): return
	for v in _vertices:
		v.color = _new_color

func undo() -> void:
	for i in range(_vertices.size()):
		_vertices[i].color = _old_colors[i]
