## Removes all items collected during one eraser stroke as a single undoable step.
## Vertices are deleted via DeleteVertexCommand (which cascades to incident edges).
## Only "standalone" edges — those whose BOTH endpoints survive — get their own
## DeleteEdgeCommand.  This prevents double-deletion of edges already owned by a
## vertex command.
class_name BulkEraseCommand
extends Command

var _edge_cmds: Array[DeleteEdgeCommand] = []
var _vertex_cmds: Array[DeleteVertexCommand] = []
var _controller: GraphController


func _init(
	g: Graph,
	vertices: Array[Vertex],
	standalone_edges: Array[Edge],
	controller: GraphController
) -> void:
	super(g)
	_controller = controller

	# Capture edge state before any deletion so snapshots are accurate.
	for e in standalone_edges:
		_edge_cmds.append(DeleteEdgeCommand.new(g, e.src.id, e.dst.id))

	# Capture vertex state (and incident edge state) before any deletion.
	for v in vertices:
		_vertex_cmds.append(DeleteVertexCommand.new(g, v))


func execute() -> void:
	var vertices: Array[Vertex] = []
	for cmd in _vertex_cmds:
		vertices.append(cmd.vertex)
	if _any_vertex_locked(vertices, "erase"):
		return

	# Standalone edges first — vertex commands will handle the rest.
	for cmd in _edge_cmds:
		cmd.execute()
	for cmd in _vertex_cmds:
		cmd.execute()

	if _controller:
		_controller.clear_selection_buffer()


func undo() -> void:
	# Restore vertices in reverse order (they were deleted last).
	var i := _vertex_cmds.size() - 1
	while i >= 0:
		_vertex_cmds[i].undo()
		i -= 1

	# Then restore standalone edges (their endpoints are back now).
	i = _edge_cmds.size() - 1
	while i >= 0:
		_edge_cmds[i].undo()
		i -= 1
