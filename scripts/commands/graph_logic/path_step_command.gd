## A macro command that bundles Vertex and Edge creation into a single Undo/Execute.
class_name PathStepCommand
extends Command

var v_cmd: AddVertexCommand
var e_cmd: AddEdgeCommand

func _init(g: Graph, pos: Vector2, prev_id: int):
	super(g)
	v_cmd = AddVertexCommand.new(g, pos)
	if prev_id != Globals.NOT_FOUND:
		# Use -1 as a placeholder for the ID we don't have yet
		e_cmd = AddEdgeCommand.new(g, prev_id, -1)

func execute() -> void:
	v_cmd.execute() # Create the vertex
	if e_cmd:
		# Give the edge the ID of the vertex we just made
		e_cmd.to_id = v_cmd.vertex.id
		e_cmd.execute() # Create teh edge

func undo() -> void:
	# Reverse order: remove connection before deleting the node
	if e_cmd: e_cmd.undo()
	v_cmd.undo()
