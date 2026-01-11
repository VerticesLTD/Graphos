extends Node2D
class_name UIEdgeView
## This script controls the "Body" of a connection between two vertices.
## It draws a line between the source and destination provided by the Brain.

## Higher value = Mouse detected from further away
const MOUSE_DETECT_SENSITIVITY = 5.0

## This is the slot for our Brain. The Graph Manager fills this when we are born.
var edge_data: Edge 

@onready var mouse_detection_area: Area2D = $MouseDetectionArea
@onready var collision_shape: CollisionShape2D = $MouseDetectionArea/CollisionShape2D


## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	GLogger.add_filter("EDGE_AREA")
	if edge_data:
		_setup_detection_area()

		# 1. Listen for edge updates (like color changes)
		edge_data.state_changed.connect(refresh)
		
		# 2. Listen for "die" commands and clear
		edge_data.vanished.connect(queue_free)		
		
		# Initial draw
		refresh()		
	else:
		# If there's no edge, delete.
		queue_free()

func _setup_detection_area():
	# Assumes edge_data exists
	var pos1 = edge_data.src.pos
	var pos2  = edge_data.dst.pos
	var width = Globals.EDGE_WIDTH + MOUSE_DETECT_SENSITIVITY

	var length: float = pos1.distance_to(pos2)
	var midpoint: Vector2 = (pos1 + pos2) / 2.0
	var rotation_angle: float = pos1.angle_to_point(pos2)

	mouse_detection_area.position = midpoint
	mouse_detection_area.rotation = rotation_angle

	if not collision_shape.shape is RectangleShape2D:
		collision_shape.shape = RectangleShape2D.new()
	
	var shape:RectangleShape2D = collision_shape.shape as RectangleShape2D

	shape.size = Vector2(length, width)


func refresh() -> void:
	# Making sure the detection area still matches what we are drawing
	_setup_detection_area()

	queue_redraw()

func _draw() -> void:
	# Stop if the brain or its endpoints are missing.
	if not edge_data or not edge_data.src or not edge_data.dst:
		return

	# We pull the positions directly from edge_data
	draw_line(edge_data.src.pos, edge_data.dst.pos, edge_data.color, Globals.EDGE_WIDTH)


func _on_mouse_entered() -> void:
	GLogger.debug("MOUSE IN", "EDGE_AREA")


func _on_mouse_exited() -> void:
	GLogger.debug("MOUSE OUT", "EDGE_AREA")
