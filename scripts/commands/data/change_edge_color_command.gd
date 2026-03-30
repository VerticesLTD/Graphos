## Command to update an edge's visual color and restore it during Undo.
class_name ChangeEdgeColorCommand
extends Command

var target_edge: Edge
var twin_edge: Edge
var new_color: Color
var old_color: Color

func _init(edge: Edge, target_color: Color):
	target_edge = edge
	new_color = target_color
	old_color = edge.color

	# If undirected, look into the destination's edges to find the one pointing back
	if edge.strategy is UndirectedStrategy:
		var current = edge.dst.edges
		while current:
			if current.dst == edge.src:
				twin_edge = current
				break
			current = current.next

func execute() -> void:
	target_edge.color = new_color
	if twin_edge:
		twin_edge.color = new_color

func undo() -> void:
	target_edge.color = old_color
	if twin_edge:
		twin_edge.color = old_color
