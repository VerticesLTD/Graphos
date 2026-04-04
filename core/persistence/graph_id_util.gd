## Generates stable, URL-safe unique identifiers for graphs.
##
## IDs are 12 lowercase hex characters (48 bits of randomness).
## Collision probability is negligible at personal-use scale.
extends RefCounted
class_name GraphIdUtil


## Returns a new random graph ID (12 hex chars, e.g. "a3f2b1c40e88").
static func generate() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := rng.randi() & 0xFFFFFF
	var b := rng.randi() & 0xFFFFFF
	return "%06x%06x" % [a, b]


## Returns true if the given string looks like a valid graph ID.
static func is_valid(id: String) -> bool:
	if id.length() != 12:
		return false
	for ch in id:
		if not ch in "0123456789abcdef":
			return false
	return true
