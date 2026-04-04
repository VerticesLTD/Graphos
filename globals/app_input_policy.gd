extends Node
## Single source of truth for when canvas/gameplay may consume input.
## GUI (LineEdit, scrollables, buttons) and OS/browser shortcuts stay usable.

func is_text_field_focused() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() as Control
	if f == null:
		return false
	if f is LineEdit or f is TextEdit:
		return true
	# SpinBox delegates to an internal line editor.
	var p: Node = f.get_parent()
	while p != null:
		if p is SpinBox:
			return true
		p = p.get_parent()
	return false


## True when the mouse is over a Control that participates in hit-testing (not IGNORE).
func is_pointer_over_blocking_control() -> bool:
	var c: Control = get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	return c.mouse_filter != Control.MOUSE_FILTER_IGNORE
