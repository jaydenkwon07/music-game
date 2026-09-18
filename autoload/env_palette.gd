extends Node
## The environment palette (M4 §3.3), loaded from data/palette.json at boot.
##
## Holds every non-note colour in the 32-colour budget: the hue-shifted rock ramp,
## the player's near-white, the resonant-architecture materials, and the UI inks.
## The twelve SATURATED note hues live in NoteColors, generated — they are the only
## saturated colours in the game (§3.3), and nothing here may use one.
##
## The whole point is that colour is DATA: rewrite palette.json and the world
## retints with no code change. So reference colours by NAME through here; never a
## hex literal in a scene or script (§3, the one rule's environment corollary).

const PALETTE_PATH := "res://data/palette.json"

var _colors: Dictionary = {}  # name (String) -> Color


func _ready() -> void:
	reload()


func reload() -> void:
	_colors.clear()
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		push_warning("EnvPalette: could not open %s." % PALETTE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EnvPalette: %s is not a JSON object." % PALETTE_PATH)
		return
	# Groups (rock/resonant/ui) are organisational only; flatten to bare names so a
	# caller asks for "rock_shadow" or "brass", not a path.
	_flatten(parsed)


func _flatten(node: Dictionary) -> void:
	for key in node:
		var value: Variant = node[key]
		if typeof(value) == TYPE_STRING and str(value).begins_with("#"):
			_colors[str(key)] = Color.html(str(value))
		elif typeof(value) == TYPE_DICTIONARY:
			_flatten(value)


## A named palette colour. Returns magenta — a loud "this colour is not in the set"
## — for an unknown name, so a typo shows on screen rather than passing silently.
func color(name: String) -> Color:
	return _colors.get(name, Color.MAGENTA)


## A named colour at an explicit alpha, for inks and outlines drawn over the world.
func with_alpha(name: String, a: float) -> Color:
	var c := color(name)
	c.a = a
	return c
