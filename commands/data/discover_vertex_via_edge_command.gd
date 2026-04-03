## Command that discovers a vertex through an edge as one logical step.
## Internally composes the existing edge and vertex color commands.
class_name DiscoverVertexViaEdgeCommand
extends Command

var _edge_cmd: ChangeEdgeColorCommand
var _vertex_cmd: ChangeVertexColorCommand

func _init(edge: Edge, vertex: Vertex, edge_color: Color, vertex_color: Color):
	_edge_cmd = ChangeEdgeColorCommand.new(edge, edge_color)
	_vertex_cmd = ChangeVertexColorCommand.new(vertex, vertex_color)

func execute() -> void:
	_edge_cmd.bypass_lock = bypass_lock
	_vertex_cmd.bypass_lock = bypass_lock
	_edge_cmd.execute()
	_vertex_cmd.execute()

func undo() -> void:
	_vertex_cmd.bypass_lock = bypass_lock
	_edge_cmd.bypass_lock = bypass_lock
	_vertex_cmd.undo()
	_edge_cmd.undo()
