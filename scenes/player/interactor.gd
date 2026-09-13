class_name Interactor
extends Node2D
## Turns `interact` (space) into a single world verb (§ owner decision, Session 8):
## picking up a note, and later talking to an NPC, reading a hint, or opening a
## door — all one key, routed to whatever the player is nearest. Lives as a child
## of the player, instantiated in player.gd, so global_position is the player's.
##
## Kept off note_input.gd (which owns NOTE input) so each stays single-purpose.

func _unhandled_input(event: InputEvent) -> void:
	# While in the instrument state, `interact` and `cancel` both leave it —
	# instant and free, no penalty (§6). Entering is a Door's job (Step 3).
	if NoteBus.instrument_state_active:
		if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
			NoteBus.set_instrument_state(false)
		return

	if not event.is_action_pressed("interact"):
		return

	# Entering the instrument state is now a Door's job (it arms its melody lock);
	# `interact` with nothing in range does nothing.
	var target := _nearest_interactable()
	if target != null:
		target.interact(get_parent())


## The closest in-range Interactable that will respond right now, or null. Reads
## the shared group rather than holding references, so any Interactable anywhere
## participates with no wiring (§4).
func _nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Interactable.IN_RANGE_GROUP):
		var candidate := node as Interactable
		if candidate == null or not candidate.can_interact():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
