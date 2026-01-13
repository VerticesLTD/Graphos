## Command to change a selection of vertices positions.
class_name MoveSelectionCommand
extends Command

# Stores { Vertex: [InitialPos, FinalPos] }
var movement_map: Dictionary = {}

func _init(selection_snapshots: Dictionary):
	# selection_snapshots should be { vertex: initial_pos }
	for v in selection_snapshots.keys():
		movement_map[v] = {
			"from": selection_snapshots[v],
			"to": v.pos # The current pos at the moment the mouse is released
		}	

func execute() -> void:
	for v in movement_map.keys():
		v.pos = movement_map[v]["to"]


func undo() -> void:
	for v in movement_map.keys():
		v.pos = movement_map[v]["from"]
