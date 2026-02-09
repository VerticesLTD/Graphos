@tool
class_name PseudoCodeData
extends Resource

const LOG_TAG = "PSEUDO_TOOL"

@export_group("Editor Tools")
## Enter code. Suffix lines with --1 or --1,2 to assign them to steps.
@export_multiline var source_text: String = ""

## Click to process.
@export var generate: bool = false:
	set(value):
		_generate_data()

@export_group("Runtime Data")
## The clean code with suffixes removed.
@export_multiline var raw_code: String

## Array of Arrays. steps[0] contains line indices for Step 1.
@export var steps: Array = [] 

func _generate_data() -> void:
	steps.clear()
	var clean_lines: PackedStringArray = []
	
	# Regex to find " --" followed by numbers/commas at end of line
	# Captures: 1=The whitespace before --, 2=The numbers string
	var regex = RegEx.new()
	regex.compile("(\\s*)--([\\d,]+)\\s*$")
	
	var source_lines: PackedStringArray = source_text.split("\n")
	var step_map: Dictionary = {} # { step_index (int): [line_indices] }
	var max_step_index: int = -1
	
	for line_idx in source_lines.size():
		var line = source_lines[line_idx]
		var match_result = regex.search(line)
		
		if match_result:
			var tag_string = match_result.get_string(2)
			var raw_step_nums = tag_string.split(",")
			
			# Add this line index to the appropriate steps
			for num_str in raw_step_nums:
				if num_str.is_valid_int():
					var step_idx = num_str.to_int() - 1 
					
					if step_idx < 0: continue # Ignore 0 or negative inputs
					
					if not step_map.has(step_idx):
						step_map[step_idx] = []
					
					step_map[step_idx].append(line_idx)
					
					if step_idx > max_step_index:
						max_step_index = step_idx
			
			# Clean the line (remove the --tags)
			# get_start(0) is the start index of the entire regex match
			var clean_line = line.left(match_result.get_start(0))
			clean_lines.append(clean_line)
			
		else:
			# No tag found, just add the line as is (belongs to no specific step)
			clean_lines.append(line)

	# Convert Dictionary to Array[Array] and fill gaps
	steps.resize(max_step_index + 1)
	for i in range(steps.size()):
		if step_map.has(i):
			steps[i] = step_map[i]
		else:
			steps[i] = [] # Empty array for skipped steps

	# Reconstruct raw code
	raw_code = "\n".join(clean_lines)
	
	notify_property_list_changed()
	if OS.has_feature("editor"):
		GLogger.info("[%s] Generated: %d lines, %d steps." % [LOG_TAG, clean_lines.size(), steps.size()],LOG_TAG)
