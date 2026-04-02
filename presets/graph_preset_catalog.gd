## Built-in preset registry. Append dicts to grow the library (3-column grid scrolls).
extends RefCounted
class_name GraphPresetCatalog

## Each entry: id, display_name, data_path (JSON), thumbnail_path (Texture2D path: .svg/.png)
static func built_in_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({
		"id": "graphos",
		"display_name": "Graphos",
		"data_path": "res://presets/data/graphos.json",
		"thumbnail_path": "res://assets/logo/SplashLogo.png",
	})
	list.append({
		"id": "petersen",
		"display_name": "Petersen",
		"data_path": "res://presets/data/petersen.json",
		"thumbnail_path": "res://assets/presets/thumb_petersen.svg",
	})
	list.append({
		"id": "kneser_62",
		"display_name": "Kneser KG(6,2)",
		"data_path": "res://presets/data/kneser_62.json",
		"thumbnail_path": "res://assets/presets/thumb_kneser.svg",
	})
	list.append({
		"id": "grid_4x4",
		"display_name": "4×4 Grid",
		"data_path": "res://presets/data/grid_4x4.json",
		"thumbnail_path": "res://assets/presets/thumb_grid_4x4.svg",
	})
	list.append({
		"id": "binary_tree",
		"display_name": "Binary Tree",
		"data_path": "res://presets/data/binary_tree.json",
		"thumbnail_path": "res://assets/presets/thumb_binary_tree.svg",
	})
	list.append({
		"id": "heart",
		"display_name": "Heart",
		"data_path": "res://presets/data/heart.json",
		"thumbnail_path": "res://assets/presets/thumb_heart.svg",
	})
	list.append({
		"id": "tesseract",
		"display_name": "Tesseract",
		"data_path": "res://presets/data/tesseract.json",
		"thumbnail_path": "res://assets/presets/thumb_tesseract.svg",
	})
	list.append({
		"id": "mobius_ladder",
		"display_name": "Möbius Ladder",
		"data_path": "res://presets/data/mobius_ladder.json",
		"thumbnail_path": "res://assets/presets/thumb_mobius.svg",
	})
	list.append({
		"id": "heawood",
		"display_name": "Heawood",
		"data_path": "res://presets/data/heawood.json",
		"thumbnail_path": "res://assets/presets/thumb_heawood.svg",
	})
	list.append({
		"id": "k33",
		"display_name": "K3,3",
		"data_path": "res://presets/data/k33.json",
		"thumbnail_path": "res://assets/presets/thumb_k33.svg",
	})
	list.append({
		"id": "flower_snark",
		"display_name": "Flower Snark",
		"data_path": "res://presets/data/flower_snark.json",
		"thumbnail_path": "res://assets/presets/thumb_flower_snark.svg",
	})
	return list
