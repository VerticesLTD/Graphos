## Command to remove a selected area based on a group of vertices.
class_name DeleteSelectionCommand
extends Command

var induced_graph: Graph
var commands: Array[Command] = []


func _init(g: Graph, selected_vertices: Array[Vertex]):
	super(g)

	# Prepare delete vertex command
	for v in selected_vertices:
		var v_cmd = DeleteVertexCommand.new(graph, v)
		commands.append(v_cmd)
			
func execute() -> void:
	# Execute them in order
	for cmd in commands:
		cmd.execute()
	
	# TBD: Update bounds box
		
func undo() -> void:
	# Execute in reverse order
	var i = commands.size() - 1
	while i >= 0:
		commands[i].undo()
		i -= 1
