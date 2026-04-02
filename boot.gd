extends Node

const CREDITS = preload("uid://c1t7e0pf81xoe")
const MAIN = preload("uid://yxcr5kwlindq")

## Set true to show the animated credits scene before main (export only; not the HTML/WASM load bar).
const SHOW_CREDITS_ON_BOOT := false

func _ready() -> void:
	if OS.has_feature("editor") or not SHOW_CREDITS_ON_BOOT:
		get_tree().change_scene_to_packed.call_deferred(MAIN)
	else:
		get_tree().change_scene_to_packed.call_deferred(CREDITS)
