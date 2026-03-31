extends CanvasLayer

@onready var panel = $PanelContainer
@onready var label = $PanelContainer/Label

# Styles
const PANEL_STYLE_ERROR_MESSAGE = preload("uid://byfaj8bd2kga0")
const PANEL_STYLE_REGULAR_MESSAGE = preload("uid://jbg50s4kkims")

var active_tween: Tween
var hidden_y: float
var shown_y: float

func _ready():
	await get_tree().process_frame
	shown_y = panel.position.y
	hidden_y = shown_y - 10.0
	panel.modulate.a = 0
	panel.position.y = hidden_y

func _fit_to_message(message: String) -> void:
	# Keep notifications compact and wrap long messages cleanly.
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var panel_width: float = clampf(text_width + 48.0, 240.0, 360.0)
	panel.custom_minimum_size = Vector2(panel_width, 50.0)

func show_error(message: String):
	panel.add_theme_stylebox_override("panel",PANEL_STYLE_ERROR_MESSAGE)
	label.text = message
	_fit_to_message(message)
	
	if active_tween:
		active_tween.kill()
	
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	active_tween.parallel().tween_property(panel, "position:y", shown_y, 0.3)
	
	# Pause
	active_tween.tween_interval(2.0)
	
	# Dissapear
	active_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	active_tween.parallel().tween_property(panel, "position:y", hidden_y, 0.4)

func show_notification(message: String):
	if active_tween:
		active_tween.kill()

	panel.add_theme_stylebox_override("panel",PANEL_STYLE_REGULAR_MESSAGE)
	label.text = message
	_fit_to_message(message)
	
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	active_tween.parallel().tween_property(panel, "position:y", shown_y, 0.3)
	
	# Pause
	active_tween.tween_interval(2.0)
	
	# Dissapear
	active_tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	active_tween.parallel().tween_property(panel, "position:y", hidden_y, 0.4)
