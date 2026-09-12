extends Node2D
## Overworld note input (§7.3). Reads the number-row palette actions and emits
## played notes on the bus. Kept off player.gd so movement stays movement.
##
## Lives as a child of the player, so global_position is the play origin the bus
## carries with each note (proximity-based effects use it). is_action_pressed
## ignores key repeat by default, so a held key plucks once, not continuously.

func _unhandled_input(event: InputEvent) -> void:
	for slot in Palette.slot_count():
		var action := "%s%d" % [InputConfig.PALETTE_ACTION_PREFIX, slot]
		if event.is_action_pressed(action):
			var midi := Palette.midi_for_slot(slot)
			if midi >= 0:
				NoteBus.play_note(midi, global_position)
			return
