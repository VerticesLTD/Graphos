extends Node

var controller: GraphController

## A map linking actions to the functions handling them
## <ACTION> : [<PRESS FUNCTION>, <RELEASE FUNCTION>]
var action_map: Dictionary = {
	&"delete" : [_handle_delete_pressed, null],
	&"copy" : [_handle_copy_pressed, null],
	&"paste" : [_handle_paste_pressed, null],
	&"cut" : [_handle_cut_pressed, null]
}

func _ready() -> void:
	var par_node = get_parent()
	if par_node is not GraphController:
		push_error("Clipboard actions node must be a child of the graph controller!")
		queue_free()
	
	controller = par_node

func _unhandled_input(event: InputEvent) -> void:
	if AppInputPolicy.is_text_field_focused():
		return
	for action: StringName in action_map.keys():
		# Callables from action map
		var pressed_handler = action_map[action].get(0)
		var release_handler = action_map[action].get(1)

		if event.is_action_pressed(action) and pressed_handler:
			pressed_handler.call(event)
			return

		if event.is_action_released(action) and release_handler:
			release_handler.call(event)
			return	

func _handle_delete_pressed(_event: InputEvent) -> void:
	var selection_buffer = controller.selection_buffer
	var graph = controller.graph

	if selection_buffer:
		CommandManager.execute(DeleteSelectionCommand.new(graph, selection_buffer, controller))

func _handle_copy_pressed(_event: InputEvent) -> void:
	var selection_buffer = controller.selection_buffer
	var graph = controller.graph

	if selection_buffer:
		# Clean up old clipboard memory
		if Globals.clipboard_graph:
			Globals.clipboard_graph.queue_free()
		
		# Create the snapshot
		Globals.clipboard_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
		GLogger.debug("Selection copied to clipboard.","CLIPBORAD")

func _handle_paste_pressed(_event: InputEvent) -> void:
	var graph = controller.graph
	
	if Globals.clipboard_graph:
		var mouse_pos = graph.get_global_mouse_position()
		
		var paste_cmd = PasteCommand.new(graph, Globals.clipboard_graph, mouse_pos, controller)

		GLogger.debug("Selection pasted.","CLIPBORAD")

		CommandManager.execute(paste_cmd)

func _handle_cut_pressed(_event: InputEvent) -> void:
	var selection_buffer = controller.selection_buffer
	var graph = controller.graph

	# Check if the buffer actually has vertices
	if not selection_buffer.is_empty():
		var cut_cmd = CutCommand.new(graph, selection_buffer, controller)
		CommandManager.execute(cut_cmd)
	else:
		GLogger.debug("Cut ignored: Selection buffer is empty.", "CLIPBOARD")
