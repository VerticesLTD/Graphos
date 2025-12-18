class_name GLogger

## Enable when debugging for info output
static var enabled := true

static var log_level = "INFO"

## Tags to filter by. If filter is none empty, only logs
## with tags inside the filter list will be printed
static var filters:Array[String] = []

static func add_filter(tag):
	filters.append(tag)

static func clear_filters():
	filters.clear()

static func debug(msg, tag=""):
	if not log_level == "DEBUG":
		return

	if filters.size() > 0 and  tag not in filters:
		return
		
	if enabled:
		print_rich("[color=orange][DEBUG][/color]","[color=cyan][",tag,"][/color] - ",msg)

static func info(msg, tag=""):
	if filters.size() > 0 and  tag not in filters:
		return
		
	if enabled:
		print_rich("[color=yellow][INFO][/color]","[color=cyan][",tag,"][/color] - ",msg)

