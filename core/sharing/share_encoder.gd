## Encodes and decodes the full graph + app state as a compressed, URL-safe base64 fragment.
##
## Pure static class — no Node, no I/O, no JavaScriptBridge.
## Safe to call from anywhere including tests.
##
## URL fragment format:  #json=<url_safe_base64_of_deflate_json>
##
## Encoding pipeline:
##   serialize → JSON.stringify (compact) → UTF-8 bytes → DEFLATE → base64url
##
## The JSON payload is identical to the .graphos format_version 2 document,
## so the same AppStateSerializer / GraphSerializer restore path is reused.
extends RefCounted
class_name ShareEncoder

const FRAGMENT_PREFIX := "json="


## Encode the current graph and view state into a #json=... URL fragment.
static func to_url_fragment(graph: Graph, camera: Camera2D, grid_enabled: bool) -> String:
	var graph_data := GraphSerializer.to_dictionary(graph)
	var app_state := AppStateSerializer.to_dictionary(camera, grid_enabled)

	var doc := {
		"format_version": GraphDocumentIO.FORMAT_VERSION,
		"next_vertex_id": graph_data["next_vertex_id"],
		"vertices": graph_data["vertices"],
		"edges": graph_data["edges"],
		"app_state": app_state,
	}

	# Compact JSON (no pretty-print) — every byte counts in a URL.
	var json := JSON.stringify(doc)
	var compressed := json.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var b64 := Marshalls.raw_to_base64(compressed)

	# Standard base64 → URL-safe base64 (RFC 4648 §5): +→- /→_ strip =
	b64 = b64.replace("+", "-").replace("/", "_").replace("=", "")

	return "#" + FRAGMENT_PREFIX + b64


## Decode a URL fragment (e.g. window.location.hash) back into a document dictionary.
## Returns { "graph_data": Dictionary, "app_state": Dictionary } on success,
## or {} on failure (corrupt data, wrong format, etc.).
static func from_url_fragment(fragment: String) -> Dictionary:
	var stripped := fragment.lstrip("#")
	if not stripped.begins_with(FRAGMENT_PREFIX):
		return {}

	var b64 := stripped.substr(FRAGMENT_PREFIX.length())
	if b64.is_empty():
		return {}

	# Restore standard base64 padding and characters.
	b64 = b64.replace("-", "+").replace("_", "/")
	var pad := b64.length() % 4
	if pad == 2:
		b64 += "=="
	elif pad == 3:
		b64 += "="

	var compressed := Marshalls.base64_to_raw(b64)
	if compressed.is_empty():
		push_error("ShareEncoder: base64 decode failed.")
		return {}

	var decompressed := compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if decompressed.is_empty():
		push_error("ShareEncoder: decompression failed.")
		return {}

	var data = JSON.parse_string(decompressed.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ShareEncoder: JSON parse failed.")
		return {}

	var ver := int(data.get("format_version", 0))
	if ver < 1 or ver > GraphDocumentIO.FORMAT_VERSION:
		push_error("ShareEncoder: unsupported format_version %d." % ver)
		return {}

	var raw_app_state = data.get("app_state", {})
	if typeof(raw_app_state) != TYPE_DICTIONARY:
		raw_app_state = {}

	return {
		"graph_data": data,
		"app_state": AppStateSerializer.from_dictionary(raw_app_state),
	}


## Returns true if the given URL fragment (e.g. window.location.hash) contains share data.
static func is_share_fragment(fragment: String) -> bool:
	return fragment.lstrip("#").begins_with(FRAGMENT_PREFIX)
