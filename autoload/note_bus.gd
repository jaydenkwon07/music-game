extends Node
## Global signal bus for played notes.
##
## Anything that reacts to a note — a door, a cracked wall, an enemy, a
## resonant crystal — listens here rather than holding a reference to the
## player. One emitter, many listeners, no coupling.
##
## M0 defines the signals and nothing emits them yet. M1 gives the player a
## way to play notes; that is the first real use.

## A note was played. `midi` is the pitch, `source` is where it came from in
## world space (some effects are proximity-based).
signal note_played(midi: int, source: Vector2)

## The player entered or left the instrument state at a door (design doc 3.6).
## While `active` is true, notes are musical only — listeners that produce
## gameplay effects must ignore note_played.
signal instrument_state_changed(active: bool)

## A door's MelodyLock armed. `targets` is the target melody as MIDI, so a
## presentational listener — the keyboard widget's melody strip — can show the
## door's STRUCTURE beside the keyboard: how many notes and their categories,
## never which specific notes (§6, the same rule the door gems obey). Mirrored
## onto the bus so that listener needs no reference to the door or the lock.
signal melody_armed(targets: Array)

## The armed melody's confirmed-note count changed — advanced by a right note, or
## reset to 0 by a wrong one. Mirrors MelodyLock.progress_changed onto the bus.
signal melody_progress(progress: int, total: int)

## A camera shake was requested (M4 Step 6). One emitter — the door unlock, the
## loop's payoff — one listener: World, which owns the camera. Bus-routed so the
## door needs no reference to the camera or the world. `strength` is peak offset in
## pixels; the listener snaps it to whole pixels so 640×360 never shimmers.
signal shake_requested(strength: float, duration: float)

var instrument_state_active: bool = false


func play_note(midi: int, source: Vector2 = Vector2.ZERO) -> void:
	note_played.emit(midi, source)


func request_shake(strength: float, duration: float) -> void:
	shake_requested.emit(strength, duration)


func set_instrument_state(active: bool) -> void:
	if instrument_state_active == active:
		return
	instrument_state_active = active
	instrument_state_changed.emit(active)


## Convenience for effect listeners: true when a note should cause something
## to happen in the world, false when the player is just making music.
func effects_enabled() -> bool:
	return not instrument_state_active
