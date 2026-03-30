extends CanvasLayer

@onready var panel = $PanelContainer
@onready var label = $PanelContainer/Label

# Styles
const PANEL_STYLE_ERROR_MESSAGE = preload("uid://byfaj8bd2kga0")
const PANEL_STYLE_REGULAR_MESSAGE = preload("uid://jbg50s4kkims")

var active_tween: Tween

func _ready():
	await get_tree().process_frame
	panel.modulate.a = 0
	panel.position.y = 40 # Starting position (tucked up)

func show_error(message: String):
	panel.add_theme_stylebox_override("panel",PANEL_STYLE_ERROR_MESSAGE)
	label.text = message
	
	if active_tween:
		active_tween.kill()
	
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	active_tween.parallel().tween_property(panel, "position:y", 70.0, 0.3)
	
	# Pause
	active_tween.tween_interval(2.0)
	
	# Dissapear
	active_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	active_tween.parallel().tween_property(panel, "position:y", 40.0, 0.4)

func show_notification(message: String):
	if active_tween:
		active_tween.kill()

	panel.add_theme_stylebox_override("panel",PANEL_STYLE_REGULAR_MESSAGE)
	label.text = message
	
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	active_tween.parallel().tween_property(panel, "position:y", 70.0, 0.3)
	
	# Pause
	active_tween.tween_interval(2.0)
	
	# Dissapear
	active_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	active_tween.parallel().tween_property(panel, "position:y", 40.0, 0.4)
