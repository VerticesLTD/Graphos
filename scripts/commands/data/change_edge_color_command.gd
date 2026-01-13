## Command to update an edge's visual color and restore it during Undo.
class_name ChangeEdgeColorCommand
extends Command

var target_edge: Edge
var new_color: Color
var old_color: Color

func _init(edge: Edge, target_color: Color, previous_color: Color):
	# Note: Modifies the Edge object directly; does not require graph structural changes.
	target_edge = edge
	new_color = target_color
	old_color = previous_color

func execute() -> void:
	target_edge.color = new_color

func undo() -> void:
	target_edge.color = old_color
