extends Node
## Single source of truth for when canvas/gameplay may consume input.
## GUI (LineEdit, scrollables, buttons) and OS/browser shortcuts stay usable.

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	# Godot's canvas key handler calls preventDefault(); the browser never sees F12 / devtools chords.
	# Capture on window runs before the event descends to the canvas, so we stop propagation only
	# for known browser-UI shortcuts and leave every other key for the game.
	_install_web_browser_shortcut_passthrough()


func _install_web_browser_shortcut_passthrough() -> void:
	var code := """
(function () {
	if (window.__graphosBrowserShortcutPassthrough) return;
	window.__graphosBrowserShortcutPassthrough = true;
	function isBrowserUiShortcut(ev) {
		var k = ev.key;
		if (k === 'F12' || k === 'F5' || k === 'F11') return true;
		if (ev.keyCode === 123 || ev.keyCode === 116 || ev.keyCode === 122) return true;
		if (ev.ctrlKey && ev.shiftKey && (k === 'I' || k === 'J' || k === 'C' || k === 'K')) return true;
		if (ev.metaKey && ev.altKey && (k === 'i' || k === 'I')) return true;
		if ((ev.ctrlKey || ev.metaKey) && (k === 'r' || k === 'R')) return true;
		return false;
	}
	window.addEventListener('keydown', function (ev) {
		if (!isBrowserUiShortcut(ev)) return;
		ev.stopPropagation();
	}, true);
})();
"""
	JavaScriptBridge.eval(code, true)


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
