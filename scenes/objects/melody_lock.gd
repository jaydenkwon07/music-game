class_name MelodyLock
extends Node
## Watches played notes while armed and decides when a melody is satisfied (§5.9).
## Thin glue: it holds NO matching logic of its own — the pure MelodyMatcher owns
## the "does the door open" decision (§4), so difficulty is tuned by editing the
## melody's match_rules in JSON, never here.
##
## Configured with only a melody id (§3): the target notes and rules are resolved
## from MelodyLibrary. Only the entered door's lock is armed at a time.

@export var melody_id: String = ""

signal unlocked
signal progress_changed(progress: int, total: int)
signal mismatch

var _armed: bool = false
var _target: Array = []
var _rules: Dictionary = {}
var _attempt: Array[int] = []


func _ready() -> void:
	# Resolve the target once so total()/target_midi() are valid before arming
	# (the door draws its gems from them at load, before the player interacts).
	_target = MelodyLibrary.get_midi(melody_id)
	_rules = MelodyLibrary.get_rules(melody_id)
	NoteBus.note_played.connect(_on_note_played)


## Begin listening: clear any prior attempt and react to played notes.
func arm() -> void:
	_attempt.clear()
	_armed = true
	progress_changed.emit(0, total())
	# Mirror onto the bus so the keyboard's melody strip can show this door's
	# structure without holding a reference to the door or this lock (§4).
	NoteBus.melody_armed.emit(_target.duplicate())
	NoteBus.melody_progress.emit(0, total())


## Stop listening and clear the attempt. Idempotent.
func disarm() -> void:
	_armed = false
	_attempt.clear()


## Target note count — drives the door's gem count.
func total() -> int:
	return _target.size()


## The target melody as MIDI, so the door can colour each gem by its note (§5.10).
func target_midi() -> Array:
	return _target


func _on_note_played(midi: int, _source: Vector2) -> void:
	# React only while armed and actually in the instrument state (§5.9) — a note
	# played in the overworld must never advance a door.
	if not _armed or not NoteBus.instrument_state_active:
		return

	_attempt.append(midi)
	var evaluation := MelodyMatcher.evaluate(_target, _attempt, _rules)
	match evaluation["result"]:
		MelodyMatcher.Result.MATCH:
			unlocked.emit()
			disarm()
		MelodyMatcher.Result.IN_PROGRESS:
			progress_changed.emit(int(evaluation["progress"]), total())
			NoteBus.melody_progress.emit(int(evaluation["progress"]), total())
		MelodyMatcher.Result.MISMATCH:
			# No penalty (§6): the buffer just resets and the gems fall dark.
			mismatch.emit()
			_attempt.clear()
			progress_changed.emit(0, total())
			NoteBus.melody_progress.emit(0, total())
