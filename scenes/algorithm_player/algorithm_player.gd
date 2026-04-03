class_name AlgorithmPlayer
extends Node2D

const LOG_TAG = "ALG_PLAYER"
const PSEUDO_MARGIN := 24.0

const _PrimScript    := preload("uid://eprimlgc7m2q")
const _KruskalScript := preload("uid://bfse1fdag2ksp")

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
	ALGORITHMS.DIJKSTRA : [Dijkstra.new(), preload("uid://c6o8phkpw1txx")],
	ALGORITHMS.PRIM     : [_PrimScript.new(), preload("uid://caqpr1m0dres0")],
	ALGORITHMS.KRUSKAL  : [_KruskalScript.new(), preload("res://algorithms/pseudo_code/Kruskal.tres")],
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

## Every vertex/edge touched by the active algorithm run is recorded here so
## _unlock_algorithm_selection() can release them all in O(n) without scanning
## the whole graph.
var _locked_vertices: Array[Vertex] = []
var _locked_edges: Array[Edge] = []

func _ready() -> void:
	pseudo_visualizer.visible = false
	pseudo_visualizer.pseudo_layout_updated.connect(_place_visualizer_bottom_left)
	algorithm_controls.visible = false
	_set_vertex_key_visuals(false, [])


func is_algorithm_running() -> bool:
	return _is_algorithm_running


## Marks every vertex in the selection — and every edge whose BOTH endpoints
## are inside the selection — as algorithm-locked.
##
## Why only edges with both endpoints inside?
## An edge is part of the algorithm's induced subgraph only when both sides
## participate.  Edges that cross the selection boundary are untouched, so the
## user can still modify that "outside" part of the graph freely.
func _lock_algorithm_selection(selection_buffer: Array[Vertex]) -> void:
	# Build a fast membership set so the edge scan below is O(degree) not O(n²).
	var id_set: Dictionary = {}
	for v: Vertex in selection_buffer:
		if is_instance_valid(v):
			id_set[v.id] = true

	for v: Vertex in selection_buffer:
		if not is_instance_valid(v):
			continue
		v.is_algorithm_locked = true
		_locked_vertices.append(v)

		# Lock every adjacency-list edge whose destination is also in the selection.
		# For undirected graphs both half-edges (v→w and w→v) are visited here,
		# so both directions end up locked automatically.
		var e: Edge = v.edges
		while e:
			if id_set.has(e.dst.id):
				e.is_algorithm_locked = true
				_locked_edges.append(e)
			e = e.next


## Releases all locks set by _lock_algorithm_selection().
## Always called after reset_to_start() so the undo-based visual restore can
## run freely before the locks come off.
func _unlock_algorithm_selection() -> void:
	for v: Vertex in _locked_vertices:
		if is_instance_valid(v):
			v.is_algorithm_locked = false
	for e: Edge in _locked_edges:
		if is_instance_valid(e):
			e.is_algorithm_locked = false
	_locked_vertices.clear()
	_locked_edges.clear()


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
		_shutdown_algorithm_for_restart()

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
	_lock_algorithm_selection(selection_buffer)


## Modular restart-safe shutdown:
## fully close current algorithm run (state + UI) before opening the next one.
func _shutdown_algorithm_for_restart() -> void:
	# Restore graph to pre-run visuals first.
	reset_to_start()

	# Unlock vertices/edges now that visuals are restored.
	_unlock_algorithm_selection()

	# Kill running UI tweens so old callbacks cannot hide new UI later.
	if visualizer_tween:
		visualizer_tween.kill()
		visualizer_tween = null
	if controls_tween:
		controls_tween.kill()
		controls_tween = null

	# Fully reset algorithm state.
	timeline.clear()
	pseudo_steps.clear()
	data_updates = []
	max_step = 0
	current_step_index = 0
	_is_algorithm_running = false

	# Fully reset controls + pseudo UI.
	algorithm_controls.reset()
	algorithm_controls.visible = false
	algorithm_controls.scale = Vector2.ONE
	pseudo_visualizer.data = null
	pseudo_visualizer.visible = false
	pseudo_visualizer.scale = Vector2.ONE

	_set_vertex_key_visuals(false, [])

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
	# First, reset visuals to go back to the original graph.
	reset_to_start()

	# Unlock vertices/edges now that visuals are restored.
	_unlock_algorithm_selection()

	# Then clear run-time data.
	timeline.clear()
	pseudo_steps.clear()
	data_updates = []
	max_step = 0
	current_step_index = 0
	_is_algorithm_running = false

	# Stop controls immediately to avoid any timer activity while collapsing.
	algorithm_controls.reset()
	_set_vertex_key_visuals(false, [])

	# Finally animate the UI out.
	_collapse_visualizer()
	_collapse_controls()
	pseudo_visualizer.data = null

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
