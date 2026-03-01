## Command to paste a sub-graph from the clipboard.
## Safely handles Undo/Redo by preserving the exact pasted vertex and edge instances.
class_name PasteCommand
extends Command

var clipboard_ref: Graph
var mouse_global_pos: Vector2
var graph_controller: GraphController

var created_vertex_cmds: Array[AddVertexCommand] = []
var created_edge_cmds: Array[AddEdgeCommand] = []

func _init(g: Graph, _clipboard: Graph, _mouse_global_pos: Vector2, _ctrl: GraphController):
	super(g)
	clipboard_ref = _clipboard
	mouse_global_pos = _mouse_global_pos
	graph_controller = _ctrl	

func execute() -> void:
	if not clipboard_ref or clipboard_ref.vertices.is_empty():
		return
		
	# Check if this is a first-time Paste or a Redo
	if created_vertex_cmds.is_empty():
		_generate_and_execute_paste()
	else:
		# REDO: Re-execute the exact same commands to restore identical IDs
		for v_cmd in created_vertex_cmds: v_cmd.execute()
		for e_cmd in created_edge_cmds: e_cmd.execute()

	# Update UI (Applies to both first-paste and redo)
	_update_selection_ui()

## Handles the complex math of translating and cloning the clipboard data
func _generate_and_execute_paste() -> void:
	var vertices_list = clipboard_ref.vertices.values()
	
	# Calculate Center
	var bounds = Rect2(vertices_list[0].pos, Vector2.ZERO)
	for v in vertices_list:
		bounds = bounds.expand(v.pos)
	var center = bounds.get_center()
	
	var id_map = {} # Maps Clipboard_ID -> New_Vertex
		
	# Paste Vertices
	for old_v in vertices_list:	
		var offset = old_v.pos - center
		var new_pos = mouse_global_pos + offset
		
		var v_cmd = AddVertexCommand.new(graph, new_pos)
		v_cmd.execute()
		created_vertex_cmds.append(v_cmd)
		id_map[old_v.id] = v_cmd.vertex
		
	# Paste Edges
	for old_v in vertices_list:
		var e = old_v.edges
		while e:
			if id_map.has(e.dst.id):
				# DELEGATION: The strategy decides if this edge needs deduplicating
				if e.strategy.should_paste_edge(old_v.id, e.dst.id):
					var new_src = id_map[old_v.id]
					var new_dst = id_map[e.dst.id]
					
					var e_cmd = AddEdgeCommand.new(
						graph, new_src.id, new_dst.id, e.weight, 
						e.strategy, e.is_weighted
					)
					e_cmd.execute()
					created_edge_cmds.append(e_cmd)
			e = e.next

## Refreshes the visual selection buffers in the controller
func _update_selection_ui() -> void:
	if graph_controller:
		graph_controller.clear_selection_buffer()
		var new_vertices: Array[Vertex] = []
		for v_cmd in created_vertex_cmds:
			new_vertices.append(v_cmd.vertex)
		graph_controller.select_vertices(new_vertices)
	
	graph_controller.update_selection_bounds()	
	
func undo() -> void:
	# Delete in reverse order: Edges first, then Vertices
	for i in range(created_edge_cmds.size() - 1, -1, -1):
		created_edge_cmds[i].undo()
	
	for i in range(created_vertex_cmds.size() - 1, -1, -1):
		created_vertex_cmds[i].undo()
		
	# Clear selection so the user doesn't have "ghost" selections
	if graph_controller:
		graph_controller.clear_selection_buffer()
