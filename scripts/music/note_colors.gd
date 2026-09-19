class_name NoteColors
extends RefCounted
## Category -> colour. PURE: no nodes, no signals, no engine state (§4 pure seam).
##
## §6, "colour is load-bearing": at 960×540 there's no room to draw a staff on a
## door, so colour is the primary channel for showing a melody. Hue comes from a
## note's *category* and its index within that category — never from pitch — and
## octave sets brightness. Every note visual in the game routes through here so
## the colour language stays consistent.
##
## This function takes category and index as values and looks nothing up (§4):
## resolving a note's category from a pitch or an id is NoteRegistry's job.

## Each category owns a contiguous arc [start, end] of the hue wheel, so a family
## reads at a glance while the four notes in it keep distinct hues (§6). Index
## 0..3 walks its category's arc. The three arcs are chosen not to overlap, so
## all twelve hues stay distinguishable on a 6px door gem; four shades of one hue
## per category was tried and rejected as unreadable at that size.
const CATEGORY_ARC := {
	"destructive": [0.00, 0.15],  # red -> orange -> amber -> yellow (warm)
	"restorative": [0.25, 0.50],  # yellow-green -> green -> teal
	"movement":    [0.60, 0.90],  # blue -> indigo -> violet -> magenta (cool)
}
const NOTES_PER_CATEGORY := 4
const SATURATION := 0.85

## Rest colour for a note with no known category — an empty slot, or a pitch
## class not yet assigned in data/notes.json (§9: only three notes exist in M2).
## Desaturated so it never reads as a real category.
const NEUTRAL := Color(0.2, 0.2, 0.24)

## Octave whose notes render at BASE_VALUE; higher octaves brighten, lower dim.
const REFERENCE_OCTAVE := 4
const BASE_VALUE := 0.9
const VALUE_PER_OCTAVE := 0.08
const MIN_VALUE := 0.5
const MAX_VALUE := 1.0


## The colour for a note, from its category, its index within that category
## (0..3), and its octave. Same category+index -> same hue at any octave; higher
## octave -> brighter. An unknown category returns NEUTRAL.
static func color(category: String, index: int, octave: int) -> Color:
	if not CATEGORY_ARC.has(category):
		return NEUTRAL
	var arc: Array = CATEGORY_ARC[category]
	var span := maxi(NOTES_PER_CATEGORY - 1, 1)
	var t := float(clampi(index, 0, NOTES_PER_CATEGORY - 1)) / float(span)
	var hue := lerpf(float(arc[0]), float(arc[1]), t)
	var value := clampf(
		BASE_VALUE + float(octave - REFERENCE_OCTAVE) * VALUE_PER_OCTAVE,
		MIN_VALUE, MAX_VALUE
	)
	return Color.from_hsv(hue, SATURATION, value)
