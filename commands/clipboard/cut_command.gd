class_name CutCommand
extends Command

var selection_to_cut: Array[Vertex]
var controller: GraphController
var internal_delete_cmd: DeleteSelectionCommand # We wrap the existing logic

func _init(g: Graph, _selection: Array[Vertex], _ctrl: GraphController):
	super(g)
	
	# Store context
	selection_to_cut = _selection.duplicate()
	controller = _ctrl
	
	internal_delete_cmd = DeleteSelectionCommand.new(graph, selection_to_cut, controller)

func execute() -> void:
	if selection_to_cut.is_empty(): return

	# Handle Clipboard (The unique part of Cut)
	if Globals.clipboard_graph:
		Globals.clipboard_graph.queue_free()
	
	Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(selection_to_cut)

	# Delegate Deletion 
	internal_delete_cmd.execute()

func undo() -> void:
	# Simply undo using the delete command!
	internal_delete_cmd.undo()
