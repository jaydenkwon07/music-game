extends Node2D
## Note input (§5.6). Two modes, switched by NoteBus.instrument_state_changed:
##
##   Overworld  — the equipped palette, mirrored to the free hand. A slot plays
##                its note at the fixed overworld octave.
##   Instrument — the full home-row piano, filtered to OWNED pitch classes; an
##                unowned key does nothing. Octave shift (`[` / `]`) applies here.
##
## Kept off player.gd so movement stays movement. Lives as a child of the player,
## so global_position is the play origin the bus carries with each note. No pitch
## literal here — the palette resolves through NoteInventory and the piano through
## InputConfig's data-driven semitone map (§3).

var _instrument_active: bool = false


func _ready() -> void:
	NoteBus.instrument_state_changed.connect(_on_instrument_state_changed)
	_instrument_active = NoteBus.instrument_state_active


func _on_instrument_state_changed(active: bool) -> void:
	_instrument_active = active
	# Every door attempt starts from the base octave (§4.2).
	if active:
		InputConfig.reset_octave()


func _unhandled_input(event: InputEvent) -> void:
	if _instrument_active:
		_handle_instrument(event)
	else:
		_handle_overworld(event)


## Overworld: number-free palette on the free hand. The piano keys are suppressed
## here — the two layouts collide by design (§6), and only one is read per mode.
func _handle_overworld(event: InputEvent) -> void:
	var actions := InputConfig.palette_actions()
	for slot in actions.size():
		if event.is_action_pressed(actions[slot]):
			var midi := NoteInventory.midi_for_slot(slot)
			if midi >= 0:
				NoteBus.play_note(midi, global_position)
			return


## Instrument state: the home-row piano. Octave keys shift the whole map; a played
## key sounds only if its pitch class is owned — unowned keys are silent (§7 Step 2).
## Notes still sound and still ring; only gameplay effects are suppressed, and that
## gate lives in the effect listeners (Resonator), not here.
func _handle_instrument(event: InputEvent) -> void:
	if event.is_action_pressed("octave_up"):
		InputConfig.shift_octave(1)
		return
	if event.is_action_pressed("octave_down"):
		InputConfig.shift_octave(-1)
		return

	for action in InputConfig.piano_actions():
		if event.is_action_pressed(action):
			var base_c := (InputConfig.piano_base_octave() + InputConfig.octave_shift() + 1) * 12
			var midi := base_c + InputConfig.piano_semitone(action)
			if NoteInventory.owns_pitch_class(NoteNames.pitch_class(midi)):
				NoteBus.play_note(midi, global_position)
			return
