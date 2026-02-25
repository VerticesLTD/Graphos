extends CanvasLayer

# Using the '$' syntax directly in the function is safer for Autoloads
func _ready():
	# Wait one frame to ensure the UI is fully loaded
	await get_tree().process_frame
	if has_node("PanelContainer"):
		$PanelContainer.modulate.a = 0
		print("Notifier System: Initialized and waiting...")

func show_error(message: String):
	print("Notifier System: showing message -> ", message)
	if not has_node("PanelContainer"):
		return
		
	$PanelContainer/Label.text = message
	var tween = create_tween()
	
	tween.tween_property($PanelContainer, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property($PanelContainer, "modulate:a", 0.0, 0.5)
