## This singleton handles user input.
## When input is detected, an "Intention" is created.
## The intention is then executed by the all objects that implement the
## `execute_intention` function and are subscribed to the intention type.
extends Node

enum INTENTION_TYPE {
	MOUSE_CLICK,
	MOUSE_MOTION,
	KEYBOARD_CLICK
	}

## Inner class representing an intention
class Intention:
	var event:InputEvent
	var position: Vector2 # position of the click
	
	func _init(input_event:InputEvent) -> void:
		self.event = input_event 
		if input_event is InputEventMouse:
			self.position = input_event.position

# Type is: Dictionary[INTENTION_TYPE,Array[Object]]
var subscribers:Dictionary = {
	INTENTION_TYPE.MOUSE_CLICK : [],
	INTENTION_TYPE.MOUSE_MOTION : [],
	INTENTION_TYPE.KEYBOARD_CLICK : [],
	}

func subscribe_to_intention(intention:INTENTION_TYPE,object:Object) -> void:
	if not INTENTION_TYPE.values().has(intention):
		push_warning("Attempted subscription with invalid intention type")
		return

	if not object.has_method("execute_intention"):
		push_warning(
			"Object attempted to subscribe to intention, but doesn't have `execute_intention` function"
			)
		return
	subscribers[intention].append(object)

func _unhandled_input(event: InputEvent) -> void:
	# Notify mouse click
	if event is InputEventMouseButton:
		var intention = Intention.new(event)
		for subscriber:Object in subscribers[INTENTION_TYPE.MOUSE_CLICK]:
			subscriber.call_deferred("execute_intention", intention)

	# Notify mouse motion
	elif event is InputEventMouseMotion:
		var intention = Intention.new(event)
		for subscriber:Object in subscribers[INTENTION_TYPE.MOUSE_MOTION]:
			subscriber.call_deferred("execute_intention", intention)
