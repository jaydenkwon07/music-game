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

var instrument_state_active: bool = false


func play_note(midi: int, source: Vector2 = Vector2.ZERO) -> void:
	note_played.emit(midi, source)


func set_instrument_state(active: bool) -> void:
	if instrument_state_active == active:
		return
	instrument_state_active = active
	instrument_state_changed.emit(active)


## Convenience for effect listeners: true when a note should cause something
## to happen in the world, false when the player is just making music.
func effects_enabled() -> bool:
	return not instrument_state_active
