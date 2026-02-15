class_name AlgorithmPlayer
extends Node2D 

const LOG_TAG = "ALG_PLAYER"

@onready var algorithm_controls: MarginContainer = $AlgorithmControls
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

# This is the pointer tracking our current point in the execution
var current_step_index: int = 0

var _is_algorithm_running := false

func _ready() -> void:
	pseudo_visualizer.visible = false

func start_algorithm(
	algorithm_type: ALGORITHMS,
	starting_node: Vertex,
	selection_buffer: Array[Vertex],
	graph: UndirectedGraph
	) -> void:
	
	if _is_algorithm_running:
		clear_all()
		if visualizer_tween:
			await visualizer_tween.finished
		_is_algorithm_running = false

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
	pseudo_steps = algorithm_result.get(1)
	assert(timeline != null and pseudo_steps != null)

	pseudo_visualizer.data = pseudo_resource
	_expose_visualizer()
	_expose_controls()

	global_position = starting_node.pos

	_is_algorithm_running = true

# Animation to show visualizer
func _expose_visualizer() -> void:
	pseudo_visualizer.visible = true
	pseudo_visualizer.scale = Vector2.ZERO

	if visualizer_tween: visualizer_tween.kill()

	visualizer_tween = create_tween()
	visualizer_tween.set_ease(visualizer_tween.EASE_OUT)
	visualizer_tween.set_trans(visualizer_tween.TRANS_BOUNCE)
	visualizer_tween.tween_property(pseudo_visualizer,"scale",Vector2.ONE,0.5)

# Animation to show player controls.
func _expose_controls() -> void:
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
func step_forward() -> void:
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

	# Move pointer forward
	current_step_index += 1

## Move to previous timeline and/or pseudo step
func step_backward() -> void:
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

## Go to a specific step
func go_to_step(target_index: int) -> void:
	target_index = clampi(target_index, 0, timeline.size() - 1)
	
	# If we need to go forward
	while current_step_index < target_index:
		step_forward()
		
	# If we need to go backward
	while current_step_index > target_index:
		step_backward()

func reset_to_start() -> void:
	go_to_step(0)

## Clear all data and collapse pseudo visualizer/controls
func clear_all() -> void:
	# First, reset visuals to go back to the original graph
	reset_to_start()
	
	# Then clear the data
	timeline.clear()
	pseudo_steps.clear()
	_collapse_visualizer()
	_collapse_controls()
	pseudo_visualizer.data = null
	current_step_index = 0
