## Manages the recording and playback of algorithms.
## Maintains a linear timeline of Actions, allowing for step-by-step navigation.
## Allows jumping a spesific state (e.g "move to state 50) - allows jumping to "critical states" of the algorithm.

class_name AlgorithmPlayer
extends RefCounted ## Acts similar to java's garbage collector

## Stores the events by order of the algorithm's execution.
var timeline: Array[Command] = []

# The Pointer: Tracks where we are in time.
# -1 = Initial State (Before the first event).
# 0 = After the first event.
var current_step_index: int = -1

## Initialize the Algorithm Player.
## @patam actions_array used to set the timeline.
func _init(actions_array: Array[Command]):
	timeline = actions_array

## 1. RECORDING (Building the Timeline)
## IMPORTANT:
## We do NOT execute it immediately here, 
## because we want to let the user "debug" and go backwards and forwards
## So we prepare it for the playback.
## @param event The event we add to the timeline
func add_event(event: Command) -> void:
	timeline.append(event)


## 2. STEP FORWARD (Next)
## The function moves to the next event in the timeline.
## We first increment the pointer to the next event, then perform the action.
func step_forward() -> void:
	# Check if we are already at the end
	if current_step_index >= timeline.size() - 1:
		return 

	# Move pointer forward
	current_step_index += 1
	
	# Execute the event at the new pointer
	var event = timeline[current_step_index]
	event.execute()

## 3. STEP BACKWARD (Previous)
## The function "undoes" the last action we had done.
## We undo the current event that we point to because its the last event we did.
func step_backward() -> void:
	# Check if we are already at the start (Initial State)
	if current_step_index < 0:
		return

	# Get the current event
	var event = timeline[current_step_index]
	
	# Undo it
	event.undo()
	
	# Move pointer backward
	current_step_index -= 1

## 4. JUMP TO STEP (Slider)
## Allows the user to drag a slider to frame 50 instantly.
## Allows jumping to "critical states" of the algorithm.
## @param target_index The index we want to jump to.
func go_to_step(target_index: int) -> void:
	# Clamp the target to valid bounds (-1 to end)
	target_index = clampi(target_index, -1, timeline.size() - 1)
	
	# If we need to go forward
	while current_step_index < target_index:
		step_forward()
		
	# If we need to go backward
	while current_step_index > target_index:
		step_backward()

## 5. RESET (Back to Initial State)
func reset_to_start() -> void:
	go_to_step(-1)

# 6. CLEAR (New Simulation)
func clear_timeline() -> void:
	# First, reset visuals to go back to the original graph
	reset_to_start()
	
	# Then clear the data
	timeline.clear()
	current_step_index = -1
