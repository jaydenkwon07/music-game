class_name NoteNames
extends RefCounted
## Pitch-name <-> MIDI-number conversion.
##
## Pure static functions. No nodes, no signals, no engine state — this is one
## half of the tested seam described in the design doc (11, Working practices).
##
## Convention: scientific pitch notation, middle C = C4 = MIDI 60.

const A4_MIDI := 69

const SEMITONE := {
	"C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3,
	"E": 4, "FB": 4, "E#": 5, "F": 5, "F#": 6, "GB": 6,
	"G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10,
	"B": 11, "CB": 11, "B#": 0,
}

const SHARP_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


## "C4" -> 60, "F#3" -> 54, "Bb2" -> 46. Returns -1 on a malformed name.
static func to_midi(note_name: String) -> int:
	var text := note_name.strip_edges()
	if text.is_empty():
		return -1

	# Walk backwards over the trailing octave digits (and a leading minus, for
	# sub-contra octaves like "C-1") to find where the letter part ends.
	var split := text.length()
	while split > 0 and (text[split - 1].is_valid_int() or text[split - 1] == "-"):
		split -= 1
	if split == 0 or split == text.length():
		return -1

	var letter := text.substr(0, split).to_upper()
	var octave_text := text.substr(split)
	if not octave_text.is_valid_int():
		return -1
	if not SEMITONE.has(letter):
		return -1

	return SEMITONE[letter] + (octave_text.to_int() + 1) * 12


## 60 -> "C4". Always spells accidentals as sharps.
static func to_name(midi: int) -> String:
	var octave := int(floor(float(midi) / 12.0)) - 1
	return SHARP_NAMES[midi % 12] + str(octave)


## 0-11, octave-independent. "Pitch class" in the design doc's Q4b sense.
static func pitch_class(midi: int) -> int:
	return ((midi % 12) + 12) % 12


## Convert a list of names to MIDI numbers. Malformed entries become -1 rather
## than throwing, so a bad data file surfaces as a visible wrong note instead
## of a crash at load.
static func list_to_midi(names: Array) -> Array[int]:
	var out: Array[int] = []
	for n in names:
		out.append(to_midi(str(n)))
	return out


## Equal-tempered frequency, for M1 when notes need to actually sound.
static func to_frequency(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - A4_MIDI) / 12.0)
