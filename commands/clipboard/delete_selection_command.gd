## Command to remove a selected area based on a group of vertices.

class_name DeleteSelectionCommand
extends Command

var commands: Array[Command] = []
var controller: GraphController # <--- ADD THIS

func _init(g: Graph, selected_vertices: Array[Vertex], _controller: GraphController):
	super(g)
	controller = _controller 
	
	var safe_selection = selected_vertices.duplicate()
	
	# Prepare delete vertex command
	for v in safe_selection:
		commands.append(DeleteVertexCommand.new(graph, v))
			
func execute() -> void:
	# Block if any vertex in the selection belongs to a running algorithm.
	for cmd in commands:
		if cmd.vertex.is_algorithm_locked:
			Notify.show_error("Cannot delete: the selection contains a vertex that is part of a running algorithm.")
			return

	for cmd in commands:
		cmd.execute()
	
	if controller:
		controller.clear_selection_buffer()		
		
func undo() -> void:
	var restored_vertices: Array[Vertex] = []
	
	# Execute in reverse order
	var i = commands.size() - 1
	while i >= 0:
		var cmd = commands[i]
		cmd.undo()
		restored_vertices.append(cmd.vertex)
		i -= 1
		
	if controller:
		controller.select_vertices(restored_vertices)
