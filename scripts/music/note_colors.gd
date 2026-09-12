class_name NoteColors
extends RefCounted
## Pitch -> colour. PURE: no nodes, no signals, no engine state (§4 pure seam).
##
## §6, "colour is load-bearing": at 320x180 there's no room to draw a staff on a
## door, so colour is the primary channel for showing a melody. Pitch class sets
## the hue — the twelve semitones wrap the hue wheel — and octave sets
## brightness. Every note visual in the game routes through here so the colour
## language stays consistent; this is not decoration and not deferred.

## Where pitch class 0 (C) sits on the hue wheel, and the saturation of every
## note. Rotate HUE_OFFSET to recolour the whole language at once.
const HUE_OFFSET := 0.0
const SATURATION := 0.85

## Octave whose notes render at BASE_VALUE; higher octaves brighten, lower dim.
const REFERENCE_OCTAVE := 4
const BASE_VALUE := 0.9
const VALUE_PER_OCTAVE := 0.08
const MIN_VALUE := 0.5
const MAX_VALUE := 1.0


## The colour for a MIDI pitch. Same pitch class -> same hue across octaves;
## higher octave -> brighter.
static func color_for_midi(midi: int) -> Color:
	var hue := fposmod(HUE_OFFSET + float(NoteNames.pitch_class(midi)) / 12.0, 1.0)
	var octave := int(floor(float(midi) / 12.0)) - 1  # MIDI: C4 = 60 -> octave 4
	var value := clampf(
		BASE_VALUE + float(octave - REFERENCE_OCTAVE) * VALUE_PER_OCTAVE,
		MIN_VALUE, MAX_VALUE
	)
	return Color.from_hsv(hue, SATURATION, value)
