extends CanvasLayer

@onready var ui_selection_rect: UISelectionRect = $UISelectionRect
@onready var vertex_tool_button: Button = $VertexToolButton

enum TOOL {
	CURSOR,
	VERTEX,
	PATH,
}

@onready var graph_controller: GraphController = $"../GraphController"

var current_tool = TOOL.VERTEX

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InputHandler.subscribe_to_intention(
		InputHandler.INTENTION_TYPE.MOUSE_CLICK,
		self
	)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func execute_intention(intention: InputHandler.Intention) -> void:
	var event:InputEventMouseButton = intention.event

	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(intention.mouse_global_pos)

func _handle_left_click(mouse_position:Vector2):
	match current_tool: 
		TOOL.VERTEX:
				graph_controller._handle_left_click(mouse_position)
				graph_controller._handle_left_release()

func _on_vertex_tool_button_pressed() -> void:
	current_tool = TOOL.VERTEX
