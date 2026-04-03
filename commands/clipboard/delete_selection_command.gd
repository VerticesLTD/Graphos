## Removes every vertex in the current selection (and their incident edges) as
## one undoable step.  Delegates to a DeleteVertexCommand per vertex so each
## one can be restored individually on undo.
class_name DeleteSelectionCommand
extends Command

var commands: Array[Command] = []
var controller: GraphController

func _init(g: Graph, selected_vertices: Array[Vertex], _controller: GraphController):
	super(g)
	controller = _controller 
	
	var safe_selection = selected_vertices.duplicate()
	
	# Prepare delete vertex command
	for v in safe_selection:
		commands.append(DeleteVertexCommand.new(graph, v))
			
func execute() -> void:
	# Collect the target vertices so the shared batch-guard helper can inspect them.
	var vertices: Array[Vertex] = []
	for cmd in commands:
		vertices.append(cmd.vertex)
	if _any_vertex_locked(vertices, "delete"): return

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
