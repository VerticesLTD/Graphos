class_name GraphStatsLayout
extends AlgorithmBaseDataLayout

var total_number_of_vertices := 0
var total_number_of_edges := 0
var current_processed_vertices := 0

@onready var graph_details: RichTextLabel = $Control/GraphDetails
@onready var processed_vertices_label: Label = $AlgorithmStatusArea/ProcessedVertices

func update_data(data) -> void:
	if data is not Dictionary:
		push_warning("BFS data update received invalid data type (expects dict)")
		return
	data = data as Dictionary

	var total_edges = data.get(&"E")
	var total_vertices = data.get(&"V")
	var processed_vertices = data.get(&"vertices_processed")

	if total_edges != null and total_edges is int:
		total_number_of_edges = total_edges	

	if total_vertices != null and total_vertices is int:
		total_number_of_vertices = total_vertices

	if processed_vertices != null and processed_vertices is int:
		current_processed_vertices = processed_vertices
	
	processed_vertices_label.text = "%d/%d" % [current_processed_vertices, total_number_of_vertices]
	graph_details.text =\
	"""
[table=2]
[cell][b]|V|[/b] = [/cell][cell]%d[/cell]
[cell][b]|E|[/b] = [/cell][cell]%d[/cell]
[/table]
	""" % [total_number_of_vertices, total_number_of_edges]

		
