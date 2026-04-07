extends Control

const POPUP_WIDTH := 328
const POPUP_HEIGHT := 150
const FEEDBACK_URL = "https://graphos-feedback.vercel.app/api/feedback"

@onready var popup: Popup = $Popup
@onready var feedback_btn: Button = $MarginContainer/SendFeedback
@onready var feedback_field: TextEdit = $Popup/PanelRoot/VBoxContainer/TextEdit

var js_window: JavaScriptObject

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not OS.has_feature("web"):
		return
	js_window = JavaScriptBridge.get_interface("window")

	JavaScriptBridge.eval("""
		window.sendFeedback = function(url, payload) {
			fetch(url, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: payload
			}).catch(err => console.error("Feedback POST failed:", err));
		};""" , true)

func _on_send_feedback_pressed() -> void:
	var gp := feedback_btn.get_global_rect()
	popup.size = Vector2i(POPUP_WIDTH, POPUP_HEIGHT)
	var x := int(gp.position.x + gp.size.x - popup.size.x)
	var y := int(gp.position.y + gp.size.y + 8)
	var vp := get_viewport().get_visible_rect().size
	x = clampi(x, 8, int(vp.x) - popup.size.x - 8)
	y = clampi(y, 8, int(vp.y) - popup.size.y - 8)
	popup.position = Vector2i(x, y)
	popup.popup()


func _on_send_pressed() -> void:
	var user_feedback = feedback_field.text
	if user_feedback.is_empty() or not OS.has_feature("web"):
		return
	var payload = JSON.stringify({"feedback":user_feedback})
	js_window.sendFeedback(FEEDBACK_URL,payload)
	
	feedback_field.text = ""
	popup.hide()
	Notify.show_notification("Thank you for your feedback!")
