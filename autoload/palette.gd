extends Node
## Loads the active note palette from data and maps number-row slots to pitches.
##
## §3, corollary: input and world objects reference a palette *slot*, never a
## pitch. Rewrite data/palettes/starter.json and every slot retunes with no
## code change. This is the overworld ability palette (note_slot_0..4); the
## instrument-state piano layout is a separate concern for a later milestone.

const PALETTE_PATH := "res://data/palettes/starter.json"

var _midi: Array[int] = []


func _ready() -> void:
	reload()


func reload() -> void:
	_midi.clear()
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Palette: could not open %s." % PALETTE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("notes"):
		push_warning("Palette: %s has no notes array." % PALETTE_PATH)
		return
	# Malformed names become -1 (NoteNames convention) rather than crashing,
	# so a bad data file surfaces as a silent slot instead of a boot failure.
	_midi = NoteNames.list_to_midi(parsed["notes"])


## MIDI pitch for a number-row slot, or -1 if the slot is empty or malformed.
func midi_for_slot(slot: int) -> int:
	if slot < 0 or slot >= _midi.size():
		return -1
	return _midi[slot]


func slot_count() -> int:
	return _midi.size()
