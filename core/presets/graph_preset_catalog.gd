## Built-in preset registry. Append dicts to grow the library (3-column grid scrolls).
extends RefCounted
class_name GraphPresetCatalog

## thumbnail_kind:
##   "static" — use thumbnail_path (Texture2D); e.g. Graphos logo PNG.
##   "live"    — render preset JSON in a SubViewport (follows Globals vertex/edge colors).
static func built_in_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []

	# ── Identity ──────────────────────────────────────────────────────────────
	list.append({
		"id": "graphos",
		"display_name": "Graphos",
		"data_path": "res://core/presets/data/graphos.json",
		"thumbnail_kind": "static",
		"thumbnail_path": "res://assets/logo/SplashLogo.png",
	})

	# ── Complete graphs ────────────────────────────────────────────────────────
	list.append({
		"id": "star_of_david",
		"display_name": "Star of David",
		"data_path": "res://core/presets/data/star_of_david.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "k5_clique",
		"display_name": "K₅ Clique",
		"data_path": "res://core/presets/data/k5_clique.json",
		"thumbnail_kind": "live",
	})

	# ── Bipartite & special structures ────────────────────────────────────────
	list.append({
		"id": "k33",
		"display_name": "K₃,₃",
		"data_path": "res://core/presets/data/k33.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "kneser_52",
		"display_name": "Kneser KG(5,2)",
		"data_path": "res://core/presets/data/kneser_52.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "butterfly",
		"display_name": "Butterfly",
		"data_path": "res://core/presets/data/butterfly.json",
		"thumbnail_kind": "live",
	})

	# ── Platonic solids ────────────────────────────────────────────────────────
	list.append({
		"id": "octahedron",
		"display_name": "Octahedron",
		"data_path": "res://core/presets/data/octahedron.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "icosahedron",
		"display_name": "Icosahedron",
		"data_path": "res://core/presets/data/icosahedron.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "dodecahedron",
		"display_name": "Dodecahedron",
		"data_path": "res://core/presets/data/dodecahedron.json",
		"thumbnail_kind": "live",
	})

	# ── Cycles & wheels ───────────────────────────────────────────────────────
	list.append({
		"id": "cycle_12",
		"display_name": "Cycle C₁₂",
		"data_path": "res://core/presets/data/cycle_12.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "wheel_w7",
		"display_name": "Wheel W₇",
		"data_path": "res://core/presets/data/wheel_w7.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "mobius_ladder",
		"display_name": "Möbius Ladder",
		"data_path": "res://core/presets/data/mobius_ladder.json",
		"thumbnail_kind": "live",
	})

	# ── Famous named graphs ───────────────────────────────────────────────────
	list.append({
		"id": "petersen",
		"display_name": "Petersen",
		"data_path": "res://core/presets/data/petersen.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "heawood",
		"display_name": "Heawood",
		"data_path": "res://core/presets/data/heawood.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "flower_snark",
		"display_name": "Flower Snark",
		"data_path": "res://core/presets/data/flower_snark.json",
		"thumbnail_kind": "live",
	})

	# ── Trees & structure ─────────────────────────────────────────────────────
	list.append({
		"id": "binary_tree",
		"display_name": "Binary Tree",
		"data_path": "res://core/presets/data/binary_tree.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "triangular_prism",
		"display_name": "Prism",
		"data_path": "res://core/presets/data/triangular_prism.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "grid_4x4",
		"display_name": "4×4 Grid",
		"data_path": "res://core/presets/data/grid_4x4.json",
		"thumbnail_kind": "live",
	})

	# ── Shapes & fun ──────────────────────────────────────────────────────────
	list.append({
		"id": "tesseract",
		"display_name": "Tesseract",
		"data_path": "res://core/presets/data/tesseract.json",
		"thumbnail_kind": "live",
	})
	list.append({
		"id": "heart",
		"display_name": "Heart",
		"data_path": "res://core/presets/data/heart.json",
		"thumbnail_kind": "live",
	})

	return list
