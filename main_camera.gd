extends Camera2D
var isDragging: bool = false
var zoomSize: float = 0.1
var zoomScale: Vector2 = Vector2(zoomSize, zoomSize)
var start_mouse_pos: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	#if user click mid mouse button then camera drag mode needs to turn on
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		isDragging = event.is_pressed()
		if isDragging:
			start_mouse_pos = get_global_mouse_position()
			
		
	if event is InputEventMouseMotion and isDragging:
		var delta = get_global_mouse_position() - start_mouse_pos
		global_position -= delta
		
	if event is InputEventMouseButton:
		if event.is_pressed():
			#zoom in
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				self.zoom += zoomScale
			#zoom out
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				self.zoom -= zoomScale
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
