class_name AlgorithmPlayer
extends Node2D 

const LOG_TAG = "ALG_PLAYER"

@onready var algorithm_controls: AlgorithmControls = $AlgorithmControls
@onready var pseudo_visualizer: PanelContainer = $PseudoVisualizer
var pseudo_steps: Array

enum ALGORITHMS {
	BFS
}

# Animations
var visualizer_tween: Tween
var controls_tween: Tween

## <ALG> : [<ALG_SCRIPT>, <PSEUDO_RES>]
var _algorithm_map: Dictionary = {
	ALGORITHMS.BFS : [BFS.new(),preload("uid://b6pr3p6u5gqym")]
	}

## Stores the events by order of the algorithm's execution.
var timeline: Array[Command] = []

## Array stored from algorithm execution. Contains updates for the controls panel data section.
var data_updates: Array

# This is the pointer tracking our current point in the execution
var current_step_index: int = 0
# Used to calculate progress of algorithm
var max_step: int

var _is_algorithm_running := false

func _ready() -> void:
	pseudo_visualizer.visible = false
	algorithm_controls.visible = false

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

	var algorithm_instance: GraphAlgorithm = _algorithm_map[algorithm_type].get(0)
	var pseudo_resource: PseudoCodeData = _algorithm_map[algorithm_type].get(1)

	assert(algorithm_instance != null)
	assert(pseudo_resource != null)

	algorithm_instance.set_alg_variables(imposter_graph,graph)

	var imposter_start_node = imposter_graph.get_vertex(starting_node.id)

	# Extracting timeline and Pseudo steps from alg run 
	var algorithm_result = algorithm_instance.run(imposter_start_node)
	timeline = algorithm_result.get(0)

	# Number of steps is the size of the timeline
	max_step = timeline.size()

	pseudo_steps = algorithm_result.get(1)
	
	data_updates = algorithm_result.get(2)
	assert(timeline != null and pseudo_steps != null and data_updates != null)


	# Setting visualizer
	pseudo_visualizer.data = pseudo_resource
	_expose_visualizer()

	algorithm_controls.set_data_layout(algorithm_type)

	# Set initial data display
	if data_updates.get(0) != null:
		algorithm_controls.update_execution_data(data_updates[0])
	_update_progress_bar()
	_expose_controls()

	global_position = starting_node.pos

	_is_algorithm_running = true

# Animation to show visualizer
func _expose_visualizer() -> void:
	pseudo_visualizer.position = Vector2.ZERO

	pseudo_visualizer.visible = true
	pseudo_visualizer.scale = Vector2.ZERO

	if visualizer_tween: visualizer_tween.kill()

	visualizer_tween = create_tween()
	visualizer_tween.set_ease(visualizer_tween.EASE_OUT)
	visualizer_tween.set_trans(visualizer_tween.TRANS_BOUNCE)
	visualizer_tween.tween_property(pseudo_visualizer,"scale",Vector2.ONE,0.5)

# Animation to show player controls.
func _expose_controls() -> void:
	algorithm_controls.position = Vector2.ZERO
	
	algorithm_controls.visible = true
	algorithm_controls.scale = Vector2.ZERO

	if controls_tween: controls_tween.kill()

	controls_tween = create_tween()
	controls_tween.set_ease(controls_tween.EASE_OUT)
	controls_tween.set_trans(controls_tween.TRANS_BOUNCE)
	controls_tween.tween_property(algorithm_controls,"scale",Vector2.ONE,0.5)

# Animation to collapse visualizer. Will be used when controls are implemented
func _collapse_visualizer() -> void:
	if visualizer_tween: visualizer_tween.kill()

	visualizer_tween = create_tween()
	visualizer_tween.set_ease(visualizer_tween.EASE_IN)
	visualizer_tween.tween_property(pseudo_visualizer,"scale",Vector2.ZERO,0.3)
	visualizer_tween.chain().tween_callback(func(): pseudo_visualizer.visible = false)


# Animation to collapse player controls. Will be used when controls are implemented
func _collapse_controls() -> void:
	if controls_tween: controls_tween.kill()

	controls_tween = create_tween()
	controls_tween.set_ease(controls_tween.EASE_IN)
	controls_tween.tween_property(algorithm_controls,"scale",Vector2.ZERO,0.3)
	controls_tween.chain().tween_callback(func(): algorithm_controls.visible = false)

## Move to next timeline and/or pseudo step
func step_forward(update_progress_bar = true) -> void:
	# Check if we are already at the end
	if current_step_index >= timeline.size():
		return 

	# event at the new pointer
	var event = timeline[current_step_index]

	var current_pseudo_step = pseudo_steps[current_step_index]

	# event Is null if we only change pseudo
	if event != null:
		GLogger.debug("Event executed",LOG_TAG)
		event.execute()

	if current_pseudo_step != null:
		GLogger.debug("Pseudo step rendered",LOG_TAG)
		pseudo_visualizer.render_step(current_pseudo_step)
	
	var data_update = data_updates[current_step_index]
	if data_update != null:
		algorithm_controls.update_execution_data(data_update)

	# Move pointer forward
	current_step_index += 1

	if update_progress_bar: _update_progress_bar()

## Move to previous timeline and/or pseudo step
func step_backward(update_progress_bar = true) -> void:
	# Check if we are already at the start (Initial State)
	if current_step_index <= 0:
		return

	# Move pointer backward
	current_step_index -= 1

	var event = timeline[current_step_index]

	var current_pseudo_step = pseudo_steps[current_step_index]
	
	if event != null:
		GLogger.debug("Event executed",LOG_TAG)
		event.undo()
	
	if current_pseudo_step != null:
		GLogger.debug("Pseudo step rendered",LOG_TAG)
		pseudo_visualizer.render_step(current_pseudo_step)
	
	var data_update = data_updates[current_step_index]
	if data_update != null:
		algorithm_controls.update_execution_data(data_update)
	
	if update_progress_bar: _update_progress_bar()

## Go to a specific step
func go_to_step(target_index: int, update_progress_bar = true) -> void:
	target_index = clampi(target_index, 0, timeline.size() - 1)
	
	# If we need to go forward
	while current_step_index < target_index:
		step_forward(update_progress_bar)
		
	# If we need to go backward
	while current_step_index > target_index:
		step_backward(update_progress_bar)

func _update_progress_bar() -> void:
	var current = float(current_step_index)
	var maximum = float(max_step)
	var progress = int(current/maximum * 100)

	algorithm_controls.set_algorithm_progress(progress)

func _on_user_changed_progress(new_value: float) -> void:
	# Transforming a float in [1,100] into a valid step number
	var step_from_val = int((max_step * new_value)/100)
	step_from_val = clampi(step_from_val,0,max_step)

	# We give 'false' to stop the progress bar from being updated.
	# Otherwise we'd have a circular update - User drags -> Player changes step -> Player updates (bad)
	go_to_step(step_from_val,false)

func reset_to_start() -> void:
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
	algorithm_controls.set_no_algorithm_data()
	algorithm_controls.set_no_algorithm_progress()
	
	_is_algorithm_running = false
