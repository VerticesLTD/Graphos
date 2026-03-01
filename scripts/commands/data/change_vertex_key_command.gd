## Command to update a vertex's key value and restore it during Undo.
class_name ChangeVertexKeyCommand
extends Command

var target_vertex: Vertex
var new_key: float # Changed to float as Keys in algorithms are often Globals.INF
var old_key: float

func _init(vertex: Vertex, target_key: float):
	# Note: Modifies the Vertex object directly; does not require graph structural changes.
	target_vertex = vertex
	new_key = target_key
	old_key = vertex.key

func execute() -> void:
	target_vertex.key = new_key

func undo() -> void:
	target_vertex.key = old_key
