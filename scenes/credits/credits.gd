extends Node2D

@onready var animation_components: Node2D = $CanvasLayer/AnimationComponents

const ANIMATION_TIME = 20.0
var animation_sprites: Array[Sprite2D] = []
var only_circles: Array[Sprite2D]
var only_vecs: Array[Sprite2D]
var tween_forward: Tween
var tween_backward: Tween
func _ready() -> void:
	for child in animation_components.get_children():
		animation_sprites.append(child)
		if child.name.contains("Vector"):
			only_vecs.append(child)
		if child.name.contains("Ellipse"):
			only_circles.append(child)

	_set_animation_forward()

func _set_animation_forward() -> void:
	if tween_forward: tween_forward.kill()
	tween_forward = create_tween()
	tween_forward.set_trans(Tween.TRANS_SINE)
	tween_forward.set_ease(Tween.EASE_IN)

	var animation_count = animation_sprites.size() - 1

	var time_per_animation = ANIMATION_TIME / animation_count 

	# Iterate over sprites, animate: Circle -> Circle -> Line connecting them
	var i = 0
	while i < animation_sprites.size():
		# First iteration is a bit tricky
		if i == 0:
			var circle1: Sprite2D = animation_sprites.get(i)	
			var circle2: Sprite2D = animation_sprites.get(i + 2)	
			var vector: Sprite2D = animation_sprites.get(i+1)

			tween_forward.tween_property(circle1,"modulate:a", 1.0, time_per_animation)
			tween_forward.tween_property(circle2,"modulate:a", 1.0, time_per_animation)
			tween_forward.tween_property(vector,"modulate:a",1.0,time_per_animation)
			
			i += 4
		else:
			var circle: Sprite2D = animation_sprites.get(i)	
			var vector: Sprite2D = animation_sprites.get(i-1)
			tween_forward.tween_property(circle,"modulate:a", 1.0, time_per_animation)
			tween_forward.tween_property(vector,"modulate:a",1.0,time_per_animation)
			i += 2

	tween_forward.tween_interval(1.0)

	# Start reversing the animation
	tween_forward.chain().tween_callback(func(): _set_animation_backward())

func _set_animation_backward() -> void:
	# Make all vectors disappear, then all circles.

	if tween_backward: tween_backward.kill()
	tween_backward = create_tween()
	tween_backward.set_trans(Tween.TRANS_SINE)
	tween_backward.set_ease(Tween.EASE_IN)

	var animation_count = animation_sprites.size() - 1

	var time_per_animation = ( ANIMATION_TIME / animation_count ) / 2


	for i in range (only_vecs.size() - 1, -1, -1):
		var vec = only_vecs.get(i)
		tween_backward.tween_property(vec,"modulate:a",0.0,time_per_animation)

	for i in range ( only_circles.size() - 1, -1, -1):
		var circ = only_circles.get(i)
		tween_backward.tween_property(circ,"modulate:a",0.0,time_per_animation)

	# Create \suspense/
	tween_backward.tween_interval(1.0)

	# Restart animation
	tween_backward.chain().tween_callback(func(): _set_animation_forward())

# Any click will start the main app
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey:
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
