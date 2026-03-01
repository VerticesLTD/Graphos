## Command to remove a vertex and all its connected edges, allowing for full restoration.
class_name DeleteVertexCommand
extends Command

var vertex: Vertex
var pos: Vector2
var edge_commands: Array[AddEdgeCommand] = []

func _init(g: Graph, v: Vertex):
	super(g)
	vertex = v
	pos = v.pos
	_capture_incident_edges()

func _capture_incident_edges() -> void:
	# We must find every edge pointing TO or FROM this vertex.
	# In a directed sandbox, vertex.get_neighbors() only finds outgoing edges!
	for v_other in graph.vertices.values():
		var edge = graph.get_edge(v_other, vertex)
		if edge:
			# We pass the edge's OWN strategy and weighted flag into the command.
			var e_cmd = AddEdgeCommand.new(
				graph, v_other.id, vertex.id, edge.weight, 
				edge.strategy, edge.is_weighted
			)
			edge_commands.append(e_cmd)

func execute() -> void:
	graph.delete_vertex(vertex)

func undo() -> void:
	graph.restore_vertex(vertex)
	for e_cmd in edge_commands:
		e_cmd.execute()
