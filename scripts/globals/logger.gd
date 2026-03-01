@tool
extends Node

## Enable when debugging for Globals.INFo output
var enabled := true

var log_level = "DEBUG"

## Tags to filter by. If filter is none empty, only logs
## with tags inside the filter list will be printed
var filters:Array[String] = []

func add_filter(tag):
	filters.append(tag)

func clear_filters():
	filters.clear()

func debug(msg, tag=""):
	if not log_level == "DEBUG":
		return

	if filters.size() > 0 and  tag not in filters:
		return
		
	if enabled:
		print_rich("[color=orange][DEBUG][/color]","[color=cyan][",tag,"][/color] - ",msg)

func Globals.INFo(msg, tag=""):
	if filters.size() > 0 and  tag not in filters:
		return
		
	if enabled:
		print_rich("[color=yellow][Globals.INFO][/color]","[color=cyan][",tag,"][/color] - ",msg)
