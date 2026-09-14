extends Node
## What the world remembers across room transitions (§6.3a, D-M3-9).
##
## Rooms are freed and re-instanced on every transition (World.enter_room, §6.2),
## so NOTHING a room contains survives leaving it unless it is recorded here. The
## slice's milestone is backtracking — the player opens D2 and takes n_step in
## Room A, wanders to Room C, and returns — and a naive re-instance would show the
## door locked again and the note lying there uncollected. This is the small,
## load-bearing piece that makes the return correct.
##
## Keyed by ID (a door's melody id, a note's id), never by node path or position,
## so moving a door or pickup in the geometry data does not lose its state. In
## memory only: this is about surviving a transition, not a relaunch — saves are
## not in M3 scope.

var _open_doors: Dictionary = {}     # door_id (melody id) -> true
var _taken_pickups: Dictionary = {}  # note_id -> true


func is_door_open(door_id: String) -> bool:
	return _open_doors.has(door_id)


func mark_door_open(door_id: String) -> void:
	_open_doors[door_id] = true


func is_pickup_taken(note_id: String) -> bool:
	return _taken_pickups.has(note_id)


func mark_pickup_taken(note_id: String) -> void:
	_taken_pickups[note_id] = true


## Debug only — clear all remembered state (e.g. a full-slice reset).
func reset() -> void:
	_open_doors.clear()
	_taken_pickups.clear()
