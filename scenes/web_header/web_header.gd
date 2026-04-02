extends PanelContainer


func _ready() -> void:
	$HBox/Title.text = ProjectSettings.get_setting("application/config/name", "Graphos")
