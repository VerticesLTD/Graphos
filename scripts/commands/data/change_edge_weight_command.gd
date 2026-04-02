## Command to update an edge's weight and restore it during Undo.
class_name ChangeEdgeWeightCommand
extends Command

var target_edge: Edge
var new_weight: float
var old_weight: float

func _init(edge: Edge, target_weight: float):
	target_edge = edge
	new_weight = target_weight
	old_weight = edge.weight

func execute() -> void:
	target_edge.weight = new_weight

func undo() -> void:
	target_edge.weight = old_weight
