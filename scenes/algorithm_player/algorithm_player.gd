class_name AlgorithmPlayer
extends Node2D

const LOG_TAG = "ALG_PLAYER"
const PSEUDO_MARGIN := 24.0

const _PrimScript := preload("res://scripts/algorithms/logic/Prim.gd")
const _KruskalScript := preload("res://scripts/algorithms/logic/Kruskal.gd")

@onready var algorithm_controls: AlgorithmControls = $UILayer/AlgorithmControls
@onready var pseudo_visualizer: PanelContainer = $UILayer/PseudoVisualizer
var pseudo_steps: Array

enum ALGORITHMS {
	BFS,
	DFS,
	DIJKSTRA,
	PRIM,
	KRUSKAL,
}

# Animations
var visualizer_tween: Tween
var controls_tween: Tween

## <ALG> : [<ALG_SCRIPT>, <PSEUDO_RES>]
var _algorithm_map: Dictionary = {
	ALGORITHMS.BFS : [BFS.new(),preload("uid://b6pr3p6u5gqym")],
	ALGORITHMS.DFS : [DFS.new(), preload("uid://chwkrpy8dpkfk")],
	ALGORITHMS.DIJKSTRA : [Dijkstra.new(), preload("res://scripts/algorithms/pseudo_code/Dijkstra.tres")],
	ALGORITHMS.PRIM : [_PrimScript.new(), preload("res://scripts/algorithms/pseudo_code/Prim.tres")],
	ALGORITHMS.KRUSKAL : [_KruskalScript.new(), preload("res://scripts/algorithms/pseudo_code/Kruskal.tres")],
}

## Stores the events by order of the algorithm's execution.
var timeline: Array[Command] = []

## Array stored from algorithm execution. Contains updates for the controls panel data section.
var data_updates: Array

## Which algorithm is running (used for optional per-algorithm HUD, e.g. Prim MST weight).
var _running_algorithm: ALGORITHMS = ALGORITHMS.BFS

# This is the pointer tracking our current point in the execution
var current_step_index: int = 0
# Used to calculate progress of algorithm
var max_step: int

var _is_algorithm_running := false

func _ready() -> void:
	pseudo_visualizer.visible = false
	pseudo_visualizer.pseudo_layout_updated.connect(_place_visualizer_bottom_left)
	algorithm_controls.visible = false
	_set_vertex_key_visuals(false, [])


func is_algorithm_running() -> bool:
	return _is_algorithm_running


# Toggles auto playing on/off
func toggle_auto_playing() -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if not _is_algorithm_running:
		return
	if algorithm_controls.is_auto_playing():
		algorithm_controls.set_auto_playing(false)
		return
	# If we finished, restart from scratch before playing again.
	if current_step_index >= timeline.size():
		reset_to_start()
	algorithm_controls.set_auto_playing(true)


func request_play() -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if not _is_algorithm_running:
		return
	if current_step_index >= timeline.size():
		reset_to_start()
	algorithm_controls.set_auto_playing(true)

func start_algorithm(
	algorithm_type: ALGORITHMS,
	starting_node: Vertex,
	selection_buffer: Array[Vertex],
	graph: Graph
	) -> void:

	if _is_algorithm_running:
		cancel_algorithm_execution()
		if visualizer_tween:
			await visualizer_tween.finished

	var imposter_graph = graph.create_induced_subgraph_from_vertices(selection_buffer)
	if imposter_graph.vertices.is_empty():
		Notify.show_error("No vertices in selection.")
		return

	var algorithm_instance: GraphAlgorithm = _algorithm_map[algorithm_type].get(0)
	var pseudo_resource: PseudoCodeData = _algorithm_map[algorithm_type].get(1)

	assert(algorithm_instance != null)
	assert(pseudo_resource != null)

	if not algorithm_instance.check_requirements(imposter_graph):
		return

	if not imposter_graph.is_weakly_connected():
		if algorithm_type == ALGORITHMS.PRIM:
			Notify.show_notification(
				"Graph is not fully connected.\n"
				+ "Prim will only span the reachable component starting from the selected vertex."
			)
		elif algorithm_type == ALGORITHMS.KRUSKAL:
			Notify.show_notification(
				"Graph is not fully connected.\n"
				+ "Kruskal will build a minimum spanning forest (one tree per component)."
			)
		else:
			Notify.show_notification(
				"Graph is not fully connected.\n"
				+ "The algorithm will only run on the reachable component starting from the selected vertex."
			)

	algorithm_instance.set_alg_variables(imposter_graph,graph)
	_set_vertex_key_visuals(
		algorithm_instance.requires_vertex_keys_display(),
		selection_buffer
	)

	var imposter_start_node: Vertex = null
	if starting_node != null:
		imposter_start_node = imposter_graph.get_vertex(starting_node.id)
	if imposter_start_node == null:
		for v: Vertex in imposter_graph.vertices.values():
			imposter_start_node = v
			break

	if imposter_start_node == null:
		Notify.show_error("Could not resolve a start vertex for this algorithm.")
		return

	# Extracting timeline and Pseudo steps from alg run
	var algorithm_result = algorithm_instance.run(imposter_start_node)
	timeline = algorithm_result.get(0)

	# Number of steps is the size of the timeline
	max_step = timeline.size()

	pseudo_steps = algorithm_result.get(1)

	data_updates = algorithm_result.get(2)
	assert(timeline != null and pseudo_steps != null and data_updates != null)

	current_step_index = 0
	_running_algorithm = algorithm_type

	# Setting visualizer
	pseudo_visualizer.data = pseudo_resource
	if pseudo_resource and pseudo_resource.steps.size() > 1:
		pseudo_visualizer.render_step(1)
	else:
		pseudo_visualizer.render_step(0)
	_expose_visualizer()

	algorithm_controls.set_step_info(0, max_step)
	_update_progress_bar()
	_sync_optional_step_data()
	_expose_controls()

	global_position = imposter_start_node.pos

	_is_algorithm_running = true

# Animation to show visualizer
func _expose_visualizer() -> void:
	pseudo_visualizer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_place_visualizer_bottom_left()
	pseudo_visualizer.scale = Vector2.ZERO

	if visualizer_tween: visualizer_tween.kill()

	visualizer_tween = create_tween()
	visualizer_tween.set_ease(visualizer_tween.EASE_OUT)
	visualizer_tween.set_trans(visualizer_tween.TRANS_BOUNCE)
	visualizer_tween.tween_property(pseudo_visualizer,"scale",Vector2.ONE,0.5)

func _place_visualizer_bottom_left() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = pseudo_visualizer.size
	pseudo_visualizer.position = Vector2(
		PSEUDO_MARGIN,
		viewport_size.y - panel_size.y - PSEUDO_MARGIN
	)

# Animation to show player controls.
func _expose_controls() -> void:
	algorithm_controls.visible = true
	algorithm_controls.scale = Vector2.ZERO

	# Wait one frame so layout settles and size is known, then set pivot to bottom-center
	await get_tree().process_frame
	algorithm_controls.pivot_offset = Vector2(
		algorithm_controls.size.x / 2.0,
		algorithm_controls.size.y
	)

	if controls_tween: controls_tween.kill()

	controls_tween = create_tween()
	controls_tween.set_ease(controls_tween.EASE_OUT)
	controls_tween.set_trans(controls_tween.TRANS_BOUNCE)
	controls_tween.tween_property(algorithm_controls,"scale",Vector2.ONE,0.5)

# Animation to collapse visualizer.
func _collapse_visualizer() -> void:
	if visualizer_tween: visualizer_tween.kill()

	visualizer_tween = create_tween()
	visualizer_tween.set_ease(visualizer_tween.EASE_IN)
	visualizer_tween.tween_property(pseudo_visualizer,"scale",Vector2.ZERO,0.3)
	visualizer_tween.chain().tween_callback(func(): pseudo_visualizer.visible = false)


# Animation to collapse player controls.
func _collapse_controls() -> void:
	if controls_tween: controls_tween.kill()

	controls_tween = create_tween()
	controls_tween.set_ease(controls_tween.EASE_IN)
	controls_tween.tween_property(algorithm_controls,"scale",Vector2.ZERO,0.3)
	controls_tween.chain().tween_callback(func(): algorithm_controls.visible = false)

## Move to next timeline and/or pseudo step
func step_forward(update_progress_bar = true) -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if timeline.is_empty() or pseudo_steps.is_empty():
		algorithm_controls.set_auto_playing(false)
		return
	# Check if we are already at the end
	if current_step_index >= timeline.size():
		algorithm_controls.set_auto_playing(false)
		return

	var step_idx := current_step_index
	if step_idx < 0 or step_idx >= timeline.size() or step_idx >= pseudo_steps.size():
		algorithm_controls.set_auto_playing(false)
		return

	# event at the new pointer
	var event = timeline[step_idx]

	var current_pseudo_step = pseudo_steps[step_idx]

	# event Is null if we only change pseudo
	if event != null:
		GLogger.debug("Event executed",LOG_TAG)
		event.execute()

	if current_pseudo_step != null:
		GLogger.debug("Pseudo step rendered",LOG_TAG)
		pseudo_visualizer.render_step(current_pseudo_step)

	# Move pointer forward
	current_step_index += 1

	if update_progress_bar:
		_update_progress_bar()
	_sync_optional_step_data()

## Move to previous timeline and/or pseudo step
func step_backward(update_progress_bar = true) -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if timeline.is_empty() or pseudo_steps.is_empty():
		return
	# Check if we are already at the start (Initial State)
	if current_step_index <= 0:
		return

	# Move pointer backward
	current_step_index -= 1
	if current_step_index < 0:
		current_step_index = 0
		return
	if current_step_index >= timeline.size() or current_step_index >= pseudo_steps.size():
		current_step_index = mini(mini(current_step_index, timeline.size()), pseudo_steps.size())
		return

	var event = timeline[current_step_index]

	var current_pseudo_step = pseudo_steps[current_step_index]

	if event != null:
		GLogger.debug("Event executed",LOG_TAG)
		event.undo()

	if current_pseudo_step != null:
		GLogger.debug("Pseudo step rendered",LOG_TAG)
		pseudo_visualizer.render_step(current_pseudo_step)

	if update_progress_bar:
		_update_progress_bar()
	_sync_optional_step_data()

## Go to a specific step
func go_to_step(target_index: int, update_progress_bar = true) -> void:
	if timeline.is_empty() or pseudo_steps.is_empty():
		current_step_index = 0
		if update_progress_bar:
			_update_progress_bar()
		_sync_optional_step_data()
		return

	target_index = clampi(target_index, 0, timeline.size())

	# If we need to go forward
	while current_step_index < target_index:
		step_forward(update_progress_bar)

	# If we need to go backward
	while current_step_index > target_index:
		step_backward(update_progress_bar)

	_sync_optional_step_data()

func _update_progress_bar() -> void:
	var current := float(current_step_index)
	var maximum := maxf(float(max_step), 1.0)
	var progress := int(roundf(current / maximum * 100.0))

	algorithm_controls.set_algorithm_progress(progress)
	algorithm_controls.set_step_info(current_step_index, max_step)

func reset_to_start() -> void:
	if timeline.is_empty() or pseudo_steps.is_empty():
		current_step_index = 0
		_sync_optional_step_data()
		return
	go_to_step(0)

## Clear all data and collapse pseudo visualizer/controls
func cancel_algorithm_execution() -> void:
	# First, reset visuals to go back to the original graph
	reset_to_start()

	# Then clear the data
	timeline.clear()
	pseudo_steps.clear()
	_collapse_visualizer()
	_collapse_controls()
	pseudo_visualizer.data = null
	current_step_index = 0
	algorithm_controls.reset()

	_is_algorithm_running = false
	_set_vertex_key_visuals(false, [])

func _sync_optional_step_data() -> void:
	if algorithm_controls == null:
		return
	if _running_algorithm != ALGORITHMS.PRIM and _running_algorithm != ALGORITHMS.KRUSKAL:
		algorithm_controls.set_optional_step_data("")
		return
	if current_step_index <= 0:
		algorithm_controls.set_optional_step_data("MST weight: 0")
		return
	var idx := current_step_index - 1
	if idx < 0 or idx >= data_updates.size():
		algorithm_controls.set_optional_step_data("")
		return
	var du = data_updates[idx]
	var mst_w := 0.0
	if du is Dictionary:
		mst_w = float(du.get(&"mst_weight", 0.0))
	algorithm_controls.set_optional_step_data("MST weight: %s" % _format_mst_weight_display(mst_w))


func _format_mst_weight_display(w: float) -> String:
	if is_equal_approx(w, roundf(w)):
		return str(int(roundf(w)))
	return str(snappedf(w, 0.01))


func _set_vertex_key_visuals(show_keys: bool, vertices: Array[Vertex]) -> void:
	var id_set := {}
	for v in vertices:
		if v:
			id_set[v.id] = true
	Globals.algorithm_key_vertex_ids = id_set
	Globals.algorithm_show_vertex_keys = show_keys
