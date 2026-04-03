## This script controls the "Body" of a vertex. 
## It is now a "Pure View": it draws its own circle and listens to the Brain.
extends Node2D
class_name UIVertexView

## Data the view pulls from
var vertex_data: Vertex

@onready var label: Label = $Label
@onready var key_badge: Node2D = $KeyBadge
@onready var key_bubble_ring: Polygon2D = $KeyBadge/BubbleRing
@onready var key_bubble: Polygon2D = $KeyBadge/Bubble
@onready var key_label: Label = $KeyBadge/KeyLabel
@onready var collision_circle: CollisionShape2D = $MouseDetectionArea/CollisionShape2D

# Drawing properties - Will be tweened for animations
var draw_radius_hovered = Globals.VERTEX_RADIUS
var draw_color_hovered = Globals.VERTEX_COLOR
const KEY_BADGE_RADIUS := 10.0
## Extra radius for the ring behind the fill (reads on white backgrounds).
const KEY_BADGE_RING_WIDTH := 1.75

# Animations
var is_hovered: bool = false
var is_manual_hover: bool = false
var _tween: Tween = null

## Called only once in the start, connects signals, and draws once.
func _ready() -> void:
	if not vertex_data:
		queue_free()
		return

	self.name = str(vertex_data.id)
	collision_circle.shape.radius = Globals.VERTEX_RADIUS

	# Connect listeners: Data changes now push updates to the View
	vertex_data.state_changed.connect(refresh)
	vertex_data.vanished.connect(_on_vanished)
	Globals.algorithm_key_visuals_changed.connect(refresh)
	
	# This allows algorithms to trigger animations via the Data
	vertex_data.animation_requested.connect(_on_animation_requested)

	refresh()
	

## ------------------------------------------------------------------------------
## VISUAL REFRESH 
## ------------------------------------------------------------------------------

## Re-syncs visual state and position with the underlying data
func refresh() -> void:
	# Pixel-align the vertex center to reduce subpixel blur.
	global_position = vertex_data.pos.round()
	label.text = str(vertex_data.id)
	self.z_index = vertex_data.z_idx

	# Pan mode should not show hover visuals.
	if Globals.current_state == Globals.State.PAN and is_hovered:
		if _tween: _tween.kill()
		is_hovered = false
		is_manual_hover = false
		draw_radius_hovered = Globals.VERTEX_RADIUS
		draw_color_hovered = vertex_data.color

	if is_hovered:
		queue_redraw()
	else:
		queue_redraw()

	_update_key_badge()
	
## This function handles the actual pixel drawing on screen.
func _draw() -> void:
	var radius: float = draw_radius_hovered if is_hovered else Globals.VERTEX_RADIUS
	var color: Color = draw_color_hovered if is_hovered else vertex_data.color
	draw_circle(Vector2.ZERO, radius, color)

func _update_key_badge() -> void:
	if not _should_show_key():
		key_badge.visible = false
		return

	key_badge.visible = true
	var ring_r: float = KEY_BADGE_RADIUS + KEY_BADGE_RING_WIDTH
	key_bubble_ring.polygon = _build_circle_polygon(ring_r, 56)
	key_bubble.polygon = _build_circle_polygon(KEY_BADGE_RADIUS, 56)
	key_label.text = _format_key(vertex_data.key)

func _should_show_key() -> bool:
	if not Globals.algorithm_show_vertex_keys:
		return false
	return Globals.algorithm_key_vertex_ids.has(vertex_data.id)

func _format_key(value: float) -> String:
	if value >= Globals.INF * 0.5:
		return "∞"
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.01))

func _build_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(point_count)
	for i in range(point_count):
		var angle := (TAU * i) / float(point_count)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points

# Called when we delete the vertex
func _on_vanished(_v: Vertex) -> void:
	queue_free()


func _on_mouse_entered() -> void:
	if Globals.current_state == Globals.State.PAN:
		return
	if is_hovered:
		return

	is_hovered = true
	_start_hover_animation()

## This function is used when external forces demand animation to start
func manual_hover_start() -> void:
	is_hovered = true
	is_manual_hover = true
	_start_hover_animation()

## Routes animation commands received from the Vertex data.
func _on_animation_requested(anim_name: String) -> void:
	if Globals.current_state == Globals.State.PAN and anim_name == "hover_start":
		return
	match anim_name:
		"hover_start":
			is_hovered = true
			is_manual_hover = true
			_start_hover_animation()
		"hover_stop":
			_stop_hover_animation()
			
func _start_hover_animation() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)

	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	# Expand the radius
	_tween.tween_property(
		self,
		"draw_radius_hovered",
		Globals.VERTEX_HOVER_SCALE * Globals.VERTEX_RADIUS,
		Globals.VERTEX_TWEEN_TIME
	)
	
	# Transition to the highlight color
	_tween.tween_property(
		self,
		"draw_color_hovered",
		Globals.VERTEX_HOVER_COLOR,
		Globals.VERTEX_TWEEN_TIME
	)
	
	# This makes the "growth" look smooth. 
	_tween.tween_method(func(_val): queue_redraw(), 0.0, 1.0, Globals.VERTEX_TWEEN_TIME)
	

func _on_mouse_exited() -> void:
	if not is_hovered or is_manual_hover:
		return
	# is_hovered will be set by the _tween!
	_stop_hover_animation()

## This function is used when external forces demand animation to stop
func manual_hover_stop() -> void:
	_stop_hover_animation()

func _stop_hover_animation() -> void:
	# Kill any current animation so they don't fight each other
	if _tween: _tween.kill()
	
	# Create a new tween and set it to run properties at the same time
	_tween = create_tween().set_parallel(true)
	
	# Back out the animation with a slight "bounce" effect for a juicy feel
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Return the circle size to the standard global radius
	_tween.tween_property(
		self,
		"draw_radius_hovered",
		Globals.VERTEX_RADIUS,
		Globals.VERTEX_TWEEN_TIME
	)
	
	# Return the color to the Brain's current color (prevents overwriting algorithm colors)
	_tween.tween_property(
		self,
		"draw_color_hovered",
		vertex_data.color,
		Globals.VERTEX_TWEEN_TIME
	)

	# Force Godot to redraw the circle every frame of this animation
	_tween.tween_method(func(_val): queue_redraw(), 0.0, 1.0, Globals.VERTEX_TWEEN_TIME)

	# Once the animation is totally finished, clean up the state flags
	_tween.chain().tween_callback(func(): 
		is_hovered = false
		is_manual_hover = false
		# Sync the hover color variable to the current data color as a final safety step
		draw_color_hovered = vertex_data.color 
		queue_redraw()
	)
