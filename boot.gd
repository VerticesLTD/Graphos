extends Control

const MAIN_PATH := "res://scenes/main/main.tscn"
## So the logo and bar are visible even when the main scene loads instantly (e.g. editor).
const MIN_DISPLAY_SEC := 0.55
const LOGO_TARGET_WIDTH := 320.0

@onready var logo: TextureRect = $CanvasLayer/CenterContainer/VBoxContainer/Logo
@onready var progress_bar: ProgressBar = $CanvasLayer/CenterContainer/VBoxContainer/ProgressBar

var _elapsed: float = 0.0
var _packed_main: PackedScene
var _load_finished: bool = false


func _ready() -> void:
	_fit_logo_and_bar_width()
	# Web export usually has thread_support disabled; threaded loading is unreliable in the browser.
	if OS.has_feature("web"):
		_start_web_load()
		return
	var err := ResourceLoader.load_threaded_request(MAIN_PATH)
	if err != OK:
		push_error("Boot: load_threaded_request failed (%s), loading main synchronously." % err)
		get_tree().change_scene_to_file.call_deferred(MAIN_PATH)


func _start_web_load() -> void:
	var main_scene: PackedScene = load(MAIN_PATH) as PackedScene
	if main_scene == null:
		push_error("Boot: failed to load main scene on Web")
		get_tree().quit(1)
		return
	_packed_main = main_scene
	_load_finished = true
	progress_bar.value = 100.0
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_PATH, progress)

	if not _load_finished:
		if progress.size() > 0:
			progress_bar.value = progress[0] * 100.0
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_load_finished = true
				progress_bar.value = 100.0
				_packed_main = ResourceLoader.load_threaded_get(MAIN_PATH) as PackedScene
				if _packed_main == null:
					push_error("Boot: main scene is not a PackedScene")
					get_tree().quit(1)
					return
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Boot: failed to load main scene")
				get_tree().quit(1)
				return

	if _load_finished and _elapsed >= MIN_DISPLAY_SEC:
		get_tree().change_scene_to_packed(_packed_main)
		set_process(false)


func _fit_logo_and_bar_width() -> void:
	var tex := logo.texture
	if tex != null:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		if tw > 0.0 and th > 0.0:
			var w: float = minf(LOGO_TARGET_WIDTH, tw)
			logo.custom_minimum_size = Vector2(w, w * th / tw)
	var bar_w: float = maxf(logo.custom_minimum_size.x, 280.0)
	progress_bar.custom_minimum_size = Vector2(bar_w, progress_bar.custom_minimum_size.y)
