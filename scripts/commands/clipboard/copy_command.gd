## Class to copy a selection, in a command.
class_name CopyCommand
extends Command

var _selection: Array[Vertex]

# We pass the graph and the specific selection we want to copy
func _init(_graph: UndirectedGraph, selection: Array[Vertex]):
	super(_graph)
	_selection = selection

func execute() -> void:
	if _selection.is_empty():
		return

	# 1. Clean up old clipboard memory
	if Globals.clipboard_graph:
		Globals.clipboard_graph.queue_free()
		Globals.clipboard_graph = null

	# 2. Create the snapshot
	# We delegate the deep copying logic to the graph class
	Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(_selection)
	
	print("Selection copied to clipboard.")

# Copying doesn't affect command history so no need for undo.
func undo() -> void:
	pass
