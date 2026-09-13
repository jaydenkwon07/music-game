extends Node
## What the player has collected, and how it maps to the overworld number-row
## slots. Replaces the fixed Palette (§7 Step 1): the player starts with NOTHING
## and gains a slot on each pickup — the design doc's cold open.
##
## §3 corollary: input and world objects reference a SLOT, never a pitch. §6
## collection model: the player collects pitch CLASSES (collecting C grants C in
## every octave), so a note is owned by id and played at a default octave in the
## overworld; the instrument state ranges to other octaves.

const MAX_SLOTS := 5
## The octave the number-row palette plays. Octave is expressive range, not a
## separate collectible (§6), so the overworld fixes one and the instrument state
## ranges around it.
const OVERWORLD_OCTAVE := 4

signal note_collected(note_id: String)

var _slots: Array[String] = []  # note_id per slot, in collection order


## Collect a note by id (resolved through NoteRegistry). Returns false if the id
## is unknown, already owned, or the inventory is full. On success the note takes
## the next free slot and note_collected fires.
func collect(note_id: String) -> bool:
	if NoteRegistry.by_id(note_id).is_empty():
		push_warning("NoteInventory: unknown note id '%s'." % note_id)
		return false
	if has(note_id) or _slots.size() >= MAX_SLOTS:
		return false
	_slots.append(note_id)
	note_collected.emit(note_id)
	return true


func has(note_id: String) -> bool:
	return _slots.has(note_id)


## Does the player own the note with this pitch class (0..11)? Used to filter the
## instrument-state piano to playable keys (Step 2).
func owns_pitch_class(pc: int) -> bool:
	for id in _slots:
		if _pitch_class_of(id) == pc:
			return true
	return false


func note_id_for_slot(slot: int) -> String:
	if slot < 0 or slot >= _slots.size():
		return ""
	return _slots[slot]


## MIDI for a number-row slot at the overworld octave, or -1 if the slot is empty.
func midi_for_slot(slot: int) -> int:
	var pc := _pitch_class_of(note_id_for_slot(slot))
	if pc < 0:
		return -1
	return (OVERWORLD_OCTAVE + 1) * 12 + pc


## Number of FILLED slots. The note bar shows one swatch per owned note and
## grows as this grows.
func slot_count() -> int:
	return _slots.size()


func owned_note_ids() -> Array[String]:
	return _slots.duplicate()


## Pitch-class integer (0..11) for a note id, or -1 if unresolved. The letter ->
## semitone conversion is NoteNames' job; no pitch literal lives here (§3).
func _pitch_class_of(note_id: String) -> int:
	if note_id.is_empty():
		return -1
	var note := NoteRegistry.by_id(note_id)
	if note.is_empty():
		return -1
	return NoteNames.SEMITONE.get(str(note["pitch_class"]).to_upper(), -1)
