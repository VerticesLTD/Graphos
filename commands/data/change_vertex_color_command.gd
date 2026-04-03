## Command to update a vertex's visual color and restore it during Undo.
class_name ChangeVertexColorCommand
extends Command

var target_vertex: Vertex
var new_color: Color
var old_color: Color

func _init(vertex: Vertex, target_color: Color):
	# Note: Modifies the Vertex object directly; does not require graph structural changes.
	target_vertex = vertex
	new_color = target_color
	old_color = vertex.color

func execute() -> void:
	target_vertex.color = new_color

func undo() -> void:
	target_vertex.color = old_color
