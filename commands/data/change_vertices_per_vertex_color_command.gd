## Sets many vertices to distinct target colors in one undo step (e.g. Kruskal make-set).
class_name ChangeVerticesPerVertexColorCommand
extends Command

var _vertices: Array[Vertex] = []
var _old_colors: Array[Color] = []
var _new_colors: Array[Color] = []

func _init(vertices: Array[Vertex], new_colors: Array[Color]) -> void:
	assert(vertices.size() == new_colors.size())
	for i in range(vertices.size()):
		var v: Vertex = vertices[i]
		if v:
			_vertices.append(v)
			_old_colors.append(v.color)
			_new_colors.append(new_colors[i])

func execute() -> void:
	if _any_vertex_locked(_vertices, "recolor"): return
	for i in range(_vertices.size()):
		_vertices[i].color = _new_colors[i]

func undo() -> void:
	for i in range(_vertices.size()):
		_vertices[i].color = _old_colors[i]
