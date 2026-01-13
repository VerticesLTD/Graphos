## This script controls the "Body" of a vertex. 
## It is now a "Pure View": it draws its own circle and listens to the Brain.
extends Node2D
class_name UIVertexView

## Data the view pulls from
var vertex_data: Vertex

@onready var label: Label = $Label
@onready var collision_circle: CollisionShape2D = $MouseDetectionArea/CollisionShape2D

# Drawing properties - Will be tweened for animations
var draw_radius_hovered = Globals.VERTEX_RADIUS
var draw_color_hovered = Globals.VERTEX_COLOR

# Animations
var is_hovered: bool = false
var tween: Tween = null

## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if vertex_data:
		self.name = str(vertex_data.id)

		# Listen for vertex updates (like if the nodes move)
		vertex_data.state_changed.connect(refresh)

		# Listen for "die" commands and clear
		vertex_data.vanished.connect(_on_vanished)

		# Setup mouse detection area to match radius
		collision_circle.shape.radius = Globals.VERTEX_RADIUS
		
		# Initial draw
		refresh()
	else:
		# If there's no data, delete.
		queue_free()

## This runs every single frame.
func _process(_delta: float) -> void:
	# Always follow the brain, good for dragging.
	global_position = vertex_data.pos
	refresh()

## ------------------------------------------------------------------------------
## VISUAL REFRESH 
## ------------------------------------------------------------------------------

## Called when something had changed.
func refresh() -> void:
	# Only repaint and relabel if the color/radius/label changed.
	label.text = str(vertex_data.id)
	self.z_index = vertex_data.z_idx
	queue_redraw()

## This function handles the actual pixel drawing on screen.
func _draw() -> void:
	# If the brain isn't plugged in yet, stop everything.
	if not vertex_data:
		return

	# If hovered, draw animated properties. Else, draw vertex_data properties
	if is_hovered:
		draw_circle(
			Vector2.ZERO,
			draw_radius_hovered,
			draw_color_hovered,
			true,
		)
	else:
		draw_circle(
			Vector2.ZERO,
			Globals.VERTEX_RADIUS,
			vertex_data.color,
			true,
		)

# Called when we delete the vertex
func _on_vanished(_v: Vertex) -> void:
	queue_free()


func _on_mouse_entered() -> void:
	is_hovered = true
	_start_hover_animation()

func _start_hover_animation() -> void:
	# Stop previous animation if running
	if tween: tween.kill()
	tween = create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"draw_radius_hovered",
		Globals.VERTEX_HOVER_SCALE * Globals.VERTEX_RADIUS,
		Globals.VERTEX_TWEEN_TIME
	)
	tween.tween_property(
		self,
		"draw_color_hovered",
		Globals.VERTEX_HOVER_COLOR,
		Globals.VERTEX_TWEEN_TIME
	)


func _on_mouse_exited() -> void:
	# is_hovered will be set by the tween!
	_stop_hover_animation()

func _stop_hover_animation() -> void:
	# Stop previous animation if running
	if tween: tween.kill()
	tween = create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"draw_radius_hovered",
		Globals.VERTEX_RADIUS,
		Globals.VERTEX_TWEEN_TIME
	)
	tween.tween_property(
		self,
		"draw_color_hovered",
		vertex_data.color,
		Globals.VERTEX_TWEEN_TIME
	)
	# Set is hovered to false when finished
	tween.chain().tween_callback(func(): is_hovered = false)
	# Prevents some bug with chaining color
	tween.chain().tween_callback(func(): draw_color_hovered = Globals.VERTEX_COLOR)
