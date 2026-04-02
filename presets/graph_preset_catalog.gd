## Built-in preset registry. Append dicts to grow the library (3-column grid scrolls).
extends RefCounted
class_name GraphPresetCatalog

## thumbnail_kind:
##   "static" — use thumbnail_path (Texture2D); e.g. Graphos logo PNG.
##   "live"    — render preset JSON in a SubViewport (follows Globals vertex/edge colors).
static func built_in_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({
		"id": "graphos",
		"display_name": "Graphos",
		"data_path": "res://presets/data/graphos.json",
		"thumbnail_kind": "static",
		"thumbnail_path": "res://assets/logo/SplashLogo.png",
	})
	list.append({
		"id": "kneser_52",
		"display_name": "Kneser KG(5,2)",
		"data_path": "res://presets/data/kneser_52.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "grid_4x4",
		"display_name": "4×4 Grid",
		"data_path": "res://presets/data/grid_4x4.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "binary_tree",
		"display_name": "Binary Tree",
		"data_path": "res://presets/data/binary_tree.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "heart",
		"display_name": "Heart",
		"data_path": "res://presets/data/heart.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "tesseract",
		"display_name": "Tesseract",
		"data_path": "res://presets/data/tesseract.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "cycle_12",
		"display_name": "Cycle C₁₂",
		"data_path": "res://presets/data/cycle_12.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "mobius_ladder",
		"display_name": "Möbius Ladder",
		"data_path": "res://presets/data/mobius_ladder.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "heawood",
		"display_name": "Heawood",
		"data_path": "res://presets/data/heawood.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "k33",
		"display_name": "K3,3",
		"data_path": "res://presets/data/k33.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "flower_snark",
		"display_name": "Flower",
		"data_path": "res://presets/data/flower_snark.json",
		"thumbnail_kind": "live",
	})
	return list
