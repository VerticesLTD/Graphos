extends CanvasLayer

@onready var ui_selection_rect: UISelectionRect = $UISelectionRect
@onready var vertex_tool_button: Button = $VertexToolButton

@onready var graph_controller: GraphController = $"../GraphController"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ui_selection_rect.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


## Should let user stay in current tool after every action
func _on_lock_tool_pressed() -> void:
	pass # Replace with function body.


func _on_drag_pressed() -> void:
	Globals.current_state = Globals.State.DRAG


func _on_vertex_pressed() -> void:
	Globals.current_state = Globals.State.VERTEX


func _on_algorithm_pressed() -> void:
	Globals.current_state = Globals.State.ALG


func _on_eraser_pressed() -> void:
	Globals.current_state = Globals.State.ERASER
