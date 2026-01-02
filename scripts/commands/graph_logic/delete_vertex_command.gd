## Command to remove a vertex and all its connected edges, allowing for full restoration.
class_name DeleteVertexCommand
extends Command

var vertex: Vertex
var pos: Vector2
var edge_commands: Array[AddEdgeCommand] = []

func _init(g: UndirectedGraph, v: Vertex):
	super(g)
	vertex = v
	pos = v.pos
	
	# Capture all connections before they are deleted
	_capture_incident_edges()

func _capture_incident_edges() -> void:
	# We look at the vertex's neighbors to see what edges exist
	var neighbors = vertex.get_neighbor_vertices()
	for n in neighbors:
		# We store an AddEdgeCommand for every connection
		var e_cmd = AddEdgeCommand.new(graph, vertex.id, n.id)
		edge_commands.append(e_cmd)

func execute() -> void:
	# Note: graph.delete_vertex already cleans up edges internally
	graph.delete_vertex(vertex)

func undo() -> void:
	# 1. Restore the vertex itself
	graph.restore_vertex(vertex)
	
	# 2. Restore all edges that were captured during _init
	for e_cmd in edge_commands:
		e_cmd.execute()
