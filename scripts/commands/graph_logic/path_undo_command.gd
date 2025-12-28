## A Macro command that bundles edge removal and vertex deletion into one step.
class_name PathUndoCommand
extends Command

var edge_cmd: DeleteEdgeCommand
var vertex_cmd: DeleteVertexCommand

func _init(g: Object, vertex: Vertex, prev_id: int):
	super(g)
	
	# 1. Always prepare the edge deletion if a connection exists
	if prev_id != Globals.NOT_FOUND:
		edge_cmd = DeleteEdgeCommand.new(g, prev_id, vertex.id)
	
	# 2. If the vertex will have no edges left, prepare to delete it
	# (Degree 1 means the edge we are about to delete is its ONLY connection)
	if vertex.degree <= 1:
		vertex_cmd = DeleteVertexCommand.new(g, vertex)

func execute() -> void:
	# Delete edge first, then vertex
	if edge_cmd: edge_cmd.execute()
	if vertex_cmd: vertex_cmd.execute()

func undo() -> void:
	# Restore in reverse: Vertex first, then Edge
	if vertex_cmd: vertex_cmd.undo()
	if edge_cmd: edge_cmd.undo()
