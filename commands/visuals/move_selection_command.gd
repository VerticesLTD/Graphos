## Command to change a selection of vertices positions.
class_name MoveSelectionCommand
extends Command

var movement_map: Dictionary = {}
var controller: GraphController

func _init(selection_snapshots: Dictionary, _controller: GraphController):
	controller = _controller
	for v in selection_snapshots.keys():
		movement_map[v] = {
			"from": selection_snapshots[v],
			"to": v.pos
		}

func execute() -> void:
	for v in movement_map.keys():
		v.pos = movement_map[v]["to"]
	controller.update_selection_bounds()

func undo() -> void:
	for v in movement_map.keys():
		v.pos = movement_map[v]["from"]
	controller.update_selection_bounds()
