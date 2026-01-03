## Command to paste a sub-graph.
class_name PasteCommand
extends Command

var clipboard_ref: UndirectedGraph
var created_vertex_cmds: Array[AddVertexCommand] = []
var created_edge_cmds: Array[AddEdgeCommand] = []
var graph_controller: GraphController

func _init(g: UndirectedGraph, _clipboard: UndirectedGraph, _mouse_global_pos: Vector2, _ctrl: GraphController):
	super(g)
	clipboard_ref = _clipboard
	graph_controller = _ctrl
	
	# Map: { Old_ID : New_ID }
	var id_map = {}
	
	# --- Step 1: Find the box ---
	var bounds = Rect2(clipboard_ref.vertices.values()[0].pos, Vector2.ZERO)
	for v in clipboard_ref.vertices.values():
		bounds = bounds.expand(v.pos)
	
	var center = bounds.get_center()
	
	# 2. Create Vertex Commands
	for old_v in clipboard_ref.vertices.values():	
		# get the vertex offset relative to the bounds center
		var offset = old_v.pos - center
		var new_pos = _mouse_global_pos + offset
		var v_cmd = AddVertexCommand.new(graph, new_pos)
		
		# Execute immediately (internally) to get the new ID assigned by the graph
		v_cmd.execute()
		created_vertex_cmds.append(v_cmd)
		
		id_map[old_v.id] = v_cmd.vertex.id
		
	# 3. Create Edges Commands
	for old_v in clipboard_ref.vertices.values():
		for neighbor in old_v.get_neighbor_vertices():
			# Avoid double-adding edges (only process if ID is smaller)
			if old_v.id < neighbor.id:
				var new_src = id_map[old_v.id]
				var new_dst = id_map[neighbor.id]
				created_edge_cmds.append(AddEdgeCommand.new(graph, new_src, new_dst))
		
	
func execute() -> void:
	for v_cmd in created_vertex_cmds:
		# We use restore here because the vertex objects already exist
		# graph.restore_vertex handles the 'already exists' check internally.
		graph.restore_vertex(v_cmd.vertex)	
		
		
	for e_cmd in created_edge_cmds:
		e_cmd.execute()
		
	# Clear the selection
	graph_controller._clear_selection_buffer()
	var new_vertices: Array[Vertex]
	for v_cmd in created_vertex_cmds:
		new_vertices.append(v_cmd.vertex)

	# Trigger the purple highlights and z-index update
	graph_controller.select_vertices(new_vertices)		

	
func undo() -> void:
	# Delete in reverse: Edges first, then Vertices
	for e_cmd in created_edge_cmds:
		e_cmd.undo()
	
	for v_cmd in created_vertex_cmds:
		v_cmd.undo()
