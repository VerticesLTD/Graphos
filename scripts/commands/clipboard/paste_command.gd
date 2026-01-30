## Command to paste a sub-graph.
class_name PasteCommand
extends Command

var clipboard_ref: UndirectedGraph
var mouse_global_pos: Vector2
var graph_controller: GraphController

var created_vertex_cmds: Array[AddVertexCommand] = []
var created_edge_cmds: Array[AddEdgeCommand] = []

func _init(g: UndirectedGraph, _clipboard: UndirectedGraph, _mouse_global_pos: Vector2, _ctrl: GraphController):
	super(g)
	clipboard_ref = _clipboard
	mouse_global_pos = _mouse_global_pos
	graph_controller = _ctrl	
		
	
func execute() -> void:
	if not clipboard_ref or clipboard_ref.vertices.is_empty():
		return
		
	# Clear old history
	created_vertex_cmds.clear()
	created_edge_cmds.clear()
	
	# 3. Calculate Center
	var bounds = Rect2(clipboard_ref.vertices.values()[0].pos, Vector2.ZERO)
	for v in clipboard_ref.vertices.values():
		bounds = bounds.expand(v.pos)
	var center = bounds.get_center()
	
	# Map: { Old_ID : New_ID }
	var id_map = {}
		
	# 4. Paste vertices
	for old_v in clipboard_ref.vertices.values():	
		# get the vertex offset relative to the bounds center
		var offset = old_v.pos - center
		var new_pos = mouse_global_pos + offset
		
		var v_cmd = AddVertexCommand.new(graph, new_pos)
		
		# Execute immediately (internally) to get the new ID assigned by the graph
		v_cmd.execute()
		created_vertex_cmds.append(v_cmd)
		
		id_map[old_v.id] = v_cmd.vertex
		
	# 3. paste edges
	for old_v in clipboard_ref.vertices.values():
		for neighbor in old_v.get_neighbor_vertices():
			# Avoid double-adding edges (only process if ID is smaller)
			if old_v.id < neighbor.id and id_map.has(neighbor.id):
				var new_src = id_map[old_v.id]
				var new_dst = id_map[neighbor.id]
				var e_cmd = AddEdgeCommand.new(graph, new_src.id, new_dst.id)
				e_cmd.execute()
				created_edge_cmds.append(e_cmd)

	# 4. Update Selection UI
	if graph_controller:
		graph_controller.clear_selection_buffer()
		var new_vertices: Array[Vertex] = []
		for v_cmd in created_vertex_cmds:
			new_vertices.append(v_cmd.vertex)

		graph_controller.select_vertices(new_vertices)
	
func undo() -> void:
	# Delete in reverse: Edges first, then Vertices
	for i in range(created_edge_cmds.size() - 1, -1, -1):
		created_edge_cmds[i].undo()
	
	for i in range(created_vertex_cmds.size() - 1, -1, -1):
		created_vertex_cmds[i].undo()
