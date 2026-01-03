class_name PopupMenuManager
extends CanvasLayer

@onready var MainMenu: PopupMenu = $MainMenu

var active = null
var mode = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MainMenu.index_pressed.connect(_on_item_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## wanna open a menu? call this function!
## @params menu_def - an array that supposed to look like that : [[command name, Command instance], [a different command name, Command instance],
## [submenu name, [  [command name, Command instance], [you get the point]  ]]
func open_menu(menu_def: Array) -> void:
	MainMenu.position = get_viewport().get_mouse_position()
	MainMenu.visible = true
	_build_menu_recursive(MainMenu, menu_def)
	MainMenu.popup()

## this method builds the actual menu
## @params menu - the PopupMenu instance we want to add items to, 
## menu_def - an array that supposed to look like that : [[command name, Command instance], [a different command name, Command instance],
## [submenu name, [  [command name, Command instance], [you get the point]  ]]
func _build_menu_recursive(menu: PopupMenu, menu_def: Array) -> void:
	menu.clear()
	for item in menu_def:
		var label = item[0]
		var value = item[1]
		
		if value is Command:
			var idx = menu.item_count # we take the amount of items in the menu to be idx
			menu.add_item(label, idx) # so the menu is 0 based
			menu.set_item_metadata(idx, value) # i.e [[0,a command],[1,different command]...]
			
		elif value is Array:
			var sub := PopupMenu.new() # the := operator not only assign things, but it also assign their type and make it static
			add_child(sub)
			menu.add_submenu_node_item(label, sub) # godot handles id automatically
			_build_menu_recursive(sub, value) # how convenient
			
			sub.mouse_exited.connect(func(): sub.hide()) # who knew gdscript has lambda functions
			
func _on_item_pressed(index: int) -> void:
	var cmd = MainMenu.get_item_metadata(index)
	if cmd is Command:
		#i'm executing the command, i also need to take care of the timeline here
		cmd.execute() # need to use command manager here!!!!!!!! i need to figure out how to grab the right arguments to pass to this function
