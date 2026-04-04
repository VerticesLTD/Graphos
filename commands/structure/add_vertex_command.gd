## Command to add a new vertex to the graph and manage its persistence for Undo/Redo.
class_name AddVertexCommand
extends Command

var pos: Vector2
var vertex: Vertex
var vertex_color: Color = Globals.VERTEX_COLOR
## True when this vertex comes from preset/clipboard paste (not a direct user click).
var from_clipboard_paste: bool = false

func _init(
		g: Graph,
		mouse_pos: Vector2,
		_vertex_color: Color = Globals.VERTEX_COLOR,
		_from_clipboard_paste: bool = false
	):
	super(g)
	pos = mouse_pos
	vertex_color = _vertex_color
	from_clipboard_paste = _from_clipboard_paste

func execute() -> void:
	if vertex == null:
		# First time execution: create the vertex
		vertex = graph.add_vertex(pos, vertex_color)
	else:
		# Redo: Re-add the exact same vertex object to the graph
		graph.restore_vertex(vertex)
		
func undo() -> void:
	if vertex:
		# Removes the vertex and its connected edges from the graph data
		graph.delete_vertex(vertex)
