## One timeline step: recolor a component merge, then add the edge to the MST (Kruskal).
class_name KruskalUnionMstCommand
extends Command

var _vertex_cmd: ChangeSelectionVertexColorCommand
var _edge_cmd: ChangeEdgeColorCommand

func _init(vertices: Array[Vertex], component_color: Color, mst_edge: Edge, mst_edge_color: Color) -> void:
	_vertex_cmd = ChangeSelectionVertexColorCommand.new(vertices, component_color)
	_edge_cmd = ChangeEdgeColorCommand.new(mst_edge, mst_edge_color)

func execute() -> void:
	_relay_bypass([_vertex_cmd, _edge_cmd])
	_vertex_cmd.execute()
	_edge_cmd.execute()

func undo() -> void:
	_relay_bypass([_vertex_cmd, _edge_cmd])
	_edge_cmd.undo()
	_vertex_cmd.undo()
