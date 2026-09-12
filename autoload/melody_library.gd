extends Node
## Loads every melody definition from res://data/melodies/ at boot.
##
## THE RULE (design doc 7.1): no pitch, melody or musical pattern ever appears
## in a script. Game code references melodies by id. If you ever find yourself
## typing a note name into a .gd file, something has gone wrong.

const MELODY_DIR := "res://data/melodies"

var _melodies: Dictionary = {}


func _ready() -> void:
	reload()
	_report_placeholders()


func reload() -> void:
	_melodies.clear()
	var dir := DirAccess.open(MELODY_DIR)
	if dir == null:
		push_warning("MelodyLibrary: %s not found." % MELODY_DIR)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var melody := _load_one(MELODY_DIR.path_join(file_name))
		if melody.is_empty():
			continue
		if not melody.has("id"):
			push_warning("MelodyLibrary: %s has no id, skipped." % file_name)
			continue
		_melodies[melody["id"]] = melody


## Returns the raw melody dictionary, or an empty one if the id is unknown.
func get_melody(id: String) -> Dictionary:
	if not _melodies.has(id):
		push_warning("MelodyLibrary: unknown melody id '%s'." % id)
		return {}
	return _melodies[id]


## The melody's notes as MIDI numbers, ready for MelodyMatcher.
func get_midi(id: String) -> Array:
	var melody := get_melody(id)
	if melody.is_empty():
		return []
	return NoteNames.list_to_midi(melody.get("notes", []))


func get_rules(id: String) -> Dictionary:
	return get_melody(id).get("match_rules", {})


func get_ids() -> Array:
	return _melodies.keys()


func _load_one(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("MelodyLibrary: could not open %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MelodyLibrary: %s is not a JSON object." % path)
		return {}
	return parsed


## Prints "N of M melodies are placeholders" on startup (design doc 7.2).
## A running count of how much of the score is still unwritten.
func _report_placeholders() -> void:
	if _melodies.is_empty():
		return
	var placeholders := 0
	for id in _melodies:
		if _melodies[id].get("placeholder", false):
			placeholders += 1
	print("MelodyLibrary: %d of %d melodies are placeholders." % [placeholders, _melodies.size()])
