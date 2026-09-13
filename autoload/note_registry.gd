extends Node
## The note registry (§5): the canonical list of notes, loaded from
## data/notes.json at boot. Every system that needs a note's category, colour or
## pitch resolves it through here.
##
## This is the single impure lookup that the pure NoteColors is deliberately kept
## free of (§4): NoteRegistry turns a pitch or an id into (category, index) and
## hands those to NoteColors. One note per pitch class (§6), so a played MIDI
## value resolves to exactly one note by its pitch class.

const NOTES_PATH := "res://data/notes.json"

var _by_id: Dictionary = {}           # id -> {id, pitch_class, category, index}
var _by_pitch_class: Dictionary = {}  # pitch-class int 0..11 -> note record


func _ready() -> void:
	reload()


func reload() -> void:
	_by_id.clear()
	_by_pitch_class.clear()
	var file := FileAccess.open(NOTES_PATH, FileAccess.READ)
	if file == null:
		push_warning("NoteRegistry: could not open %s." % NOTES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("notes"):
		push_warning("NoteRegistry: %s has no notes array." % NOTES_PATH)
		return
	for entry in parsed["notes"]:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		var note := {
			"id": str(entry.get("id", "")),
			"pitch_class": str(entry.get("pitch_class", "")),
			"category": str(entry.get("category", "")),
			"index": int(entry.get("index", 0)),
		}
		_by_id[note["id"]] = note
		# Key by pitch-class integer so any octave of the note resolves to it.
		var pc: int = NoteNames.SEMITONE.get(note["pitch_class"].to_upper(), -1)
		if pc >= 0:
			_by_pitch_class[pc] = note


## The note record for an id, or {} if unknown.
func by_id(id: String) -> Dictionary:
	return _by_id.get(id, {})


## The note record whose pitch class matches this MIDI value (octave-independent),
## or {} if that pitch class isn't in the registry yet.
func by_midi(midi: int) -> Dictionary:
	return _by_pitch_class.get(NoteNames.pitch_class(midi), {})


## The colour for a played or equipped MIDI pitch: resolve its category and index
## here, then hand them plus the octave to the pure NoteColors. An unknown pitch
## class (only three are assigned in M2, §9) falls back to NoteColors.NEUTRAL.
func color_for_midi(midi: int) -> Color:
	if midi < 0:
		return NoteColors.NEUTRAL
	var note := by_midi(midi)
	if note.is_empty():
		return NoteColors.NEUTRAL
	var octave := int(floor(float(midi) / 12.0)) - 1  # MIDI: C4 = 60 -> octave 4
	return NoteColors.color(note["category"], note["index"], octave)
