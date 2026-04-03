## Command to remove a vertex and its edges, allowing for full restoration.
class_name DeleteVertexCommand
extends Command

var vertex: Vertex
var edge_commands: Array[AddEdgeCommand] = []

func _init(g: Graph, v: Vertex):
	super(g)
	vertex = v
	_capture_incident_edges()

func _capture_incident_edges() -> void:
	# Capture Outgoing Edges 
	var curr = vertex.edges
	while curr:
		edge_commands.append(_create_edge_cmd(curr))
		curr = curr.next

	# Capture Incoming Edges 
	# DELEGATION: We ask the edge's specific strategy if it needs to be saved
	for e in graph.get_incoming_edges(vertex):
		if e.strategy.requires_incoming_capture():
			edge_commands.append(_create_edge_cmd(e))

## Helper to create a snapshot command of an existing edge's data
func _create_edge_cmd(e: Edge) -> AddEdgeCommand:
	return AddEdgeCommand.new(
		graph, e.src.id, e.dst.id, e.weight, e.strategy, e.is_weighted, e.color
	)

func execute() -> void:
	if vertex.is_algorithm_locked:
		Notify.show_error("Cannot delete: this vertex is part of a running algorithm.")
		return
	graph.delete_vertex(vertex)

func undo() -> void:
	graph.restore_vertex(vertex)
	for e_cmd in edge_commands:
		e_cmd.execute()
