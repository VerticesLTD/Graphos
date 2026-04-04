## Graph-wide animation orchestration (selection highlights, hover sync).
## Keeps graph_controller.gd from growing a second animation system.
class_name AnimationManager
extends Node

var old_selection: Array[Vertex] = []
var current_selection: Array[Vertex] = []

func update_current_selection(new_selection: Array[Vertex], update_animations: bool = true) -> void:
	old_selection = current_selection.duplicate()
	current_selection = new_selection.duplicate()

	if update_animations:
		update_selected_elements_hover_animations()


## Syncs “selection glow” on vertices and internal edges. Always tears down highlights for
## deselected items first, then starts glow for the new set — unless pan/eraser forbid it.
func update_selected_elements_hover_animations() -> void:
	var current_ids: Dictionary = {}
	for v in current_selection:
		current_ids[v.id] = true

	var stopped_edges: Dictionary = {}

	# Phase 1 — anything that left the selection loses highlight (always, every tool).
	for v in old_selection:
		if not is_instance_valid(v):
			continue
		if current_ids.has(v.id):
			continue
		v.animation_requested.emit("hover_stop")
		var e = v.edges
		while e:
			if is_instance_valid(e):
				var stop_edge_id: int = e.get_instance_id()
				if stopped_edges.has(stop_edge_id):
					e = e.next
					continue
				stopped_edges[stop_edge_id] = true
				e.animation_requested.emit("hover_stop")
			e = e.next

	# Phase 2 — pan / eraser: never start new selection glow (views also skip pointer hover).
	if Globals.graph_hover_highlights_disabled():
		return

	var started_edges: Dictionary = {}
	for v in current_selection:
		v.animation_requested.emit("hover_start")
		var e2 = v.edges
		while e2:
			if current_ids.has(e2.dst.id):
				var edge_id: int = e2.get_instance_id()
				if not started_edges.has(edge_id):
					started_edges[edge_id] = true
					e2.animation_requested.emit("hover_start")
			e2 = e2.next

## Force-stops all highlights for the current selection.
func clear_all_selection_hovers() -> void:
	for v in current_selection:
		if is_instance_valid(v):
			v.animation_requested.emit("hover_stop")
			
			var e = v.edges
			while e:
				if is_instance_valid(e):
					e.animation_requested.emit("hover_stop")
				e = e.next
