class_name CutCommand
extends Command

var selection_to_cut: Array[Vertex]
var graph_controller: GraphController

# Store sub-commands to handle the actual deletion logic
var delete_cmds: Array[DeleteVertexCommand] = []

func _init(g: Graph, _selection: Array[Vertex], _ctrl: GraphController):
	super(g)
	# Deep copy the array so we remember exactly what was selected at this moment
	selection_to_cut = _selection.duplicate()
	graph_controller = _ctrl

func execute() -> void:
	if selection_to_cut.is_empty():
		return

	# Update clipboard
	if Globals.clipboard_graph:
		Globals.clipboard_graph.queue_free()
	
	# Create snapshot of the vertices we are about to delete
	Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(selection_to_cut)
	Notify.show_notification("Copied to clip-board.")

	# Delete logic
	if delete_cmds.is_empty():
		# First run: Create the delete commands
		for v in selection_to_cut:
			# DeleteVertexCommand handles removing edges connected to v
			var cmd = DeleteVertexCommand.new(graph, v)
			cmd.execute()
			delete_cmds.append(cmd)
	else:
		# Redo run: Just re-execute existing commands
		for cmd in delete_cmds:
			cmd.execute()

	# Cleanup UI
	if graph_controller:
		graph_controller.clear_selection_buffer()
		# TBD: Make the next line work
		graph_controller.update_selection_bounds()
		
		

func undo() -> void:
	# Undo deletion in reverse order
	for i in range(delete_cmds.size() - 1, -1, -1):
		delete_cmds[i].undo()
		
	# Restore selection so the user sees the nodes came back
	if graph_controller:
		graph_controller.select_vertices(selection_to_cut)
