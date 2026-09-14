class_name InstrumentKeyboardLayout
extends RefCounted
## One-octave piano geometry for the instrument-state keyboard widget (M3
## addendum). PURE: no nodes, no signals, no engine state (§4 pure seam) — it
## turns a white-key size into slot rectangles the widget draws, so the geometry
## is unit-testable without booting the engine.
##
## This is geometry, not content: it maps the twelve chromatic SEMITONES of one
## octave onto white/black key positions. No pitch NAME and no melody appears
## here (§3) — the key letters and the semitone->key binding come from the
## data-driven InputConfig, never from this file.

## The seven white-key semitones of an octave (C D E F G A B) as offsets 0..11.
## Every other offset in 0..11 is a black key. Fixed piano geometry — the same
## shape the home-row layout was chosen to mirror (§6) — not swappable content.
const WHITE_SEMITONES := [0, 2, 4, 5, 7, 9, 11]

## A black key's width as a fraction of a white key's. Presentational.
const BLACK_WIDTH_RATIO := 0.62


## Slot rectangles for one octave, in semitone order 0..11. Each entry is
## { semitone:int, white:bool, rect:Rect2 }. Whites form a row of `white_w`-wide
## keys separated by `gap`; each black is centred on the boundary between the two
## whites it sits between, at BLACK_WIDTH_RATIO of a white's width. Whites are
## `white_h` tall, blacks `black_h`, both sharing the top edge (y = 0). The real
## gaps at E-F and B-C fall out for free: no black key has those semitones.
static func slots(white_w: float, gap: float, white_h: float, black_h: float) -> Array:
	var out: Array = []
	var black_w := white_w * BLACK_WIDTH_RATIO
	for semitone in 12:
		var whites_below := _whites_below(semitone)
		if WHITE_SEMITONES.has(semitone):
			# whites_below is this white key's index in the row.
			var wx := whites_below * (white_w + gap)
			out.append({
				"semitone": semitone,
				"white": true,
				"rect": Rect2(wx, 0.0, white_w, white_h),
			})
		else:
			# Sits between white (whites_below - 1) and white whites_below: centre
			# it on the gap between them.
			var boundary := whites_below * (white_w + gap) - gap * 0.5
			out.append({
				"semitone": semitone,
				"white": false,
				"rect": Rect2(boundary - black_w * 0.5, 0.0, black_w, black_h),
			})
	return out


## Total width of the white-key row, so the widget can centre the whole keyboard.
static func row_width(white_w: float, gap: float) -> float:
	var n := WHITE_SEMITONES.size()
	return n * white_w + (n - 1) * gap


## Number of white semitones strictly below `semitone`. For a white key that is
## its index in the row; for a black key it also fixes which two whites it lies
## between (whites_below - 1 on the left, whites_below on the right).
static func _whites_below(semitone: int) -> int:
	var n := 0
	for w in WHITE_SEMITONES:
		if w < semitone:
			n += 1
	return n
