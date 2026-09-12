class_name MelodyMatcher
extends RefCounted
## Decides whether a sequence of played notes satisfies a target melody.
##
## Pure static functions — no nodes, no engine state, no knowledge of doors.
## A door, a boss weakness and a secret passage all call the same function
## with different data (design doc 7.3).
##
## Everything about *how* strictly to compare lives in the melody's
## match_rules dictionary, not in here and not in any caller. That is what
## makes difficulty tunable from a JSON file with no code change.

enum Result { MISMATCH, IN_PROGRESS, MATCH }

const DEFAULT_RULES := {
	"order_matters": true,
	"octave_matters": false,
	"allow_transposition": false,
	"timing_matters": false,  # reserved; M2+ ignores rhythm entirely
}


## Evaluate a full or partial attempt against a target.
##
## target_midi:  Array[int] — the melody, as MIDI numbers
## attempt_midi: Array[int] — what the player has played so far
## rules:        Dictionary — any subset of DEFAULT_RULES
##
## Returns { "result": Result, "progress": int }
##   progress = how many notes are confirmed correct so far. Drives the door
##   gems lighting up one at a time (design doc 3.6, "structure").
static func evaluate(target_midi: Array, attempt_midi: Array, rules: Dictionary = {}) -> Dictionary:
	var r := _merged_rules(rules)

	if target_midi.is_empty():
		return {"result": Result.MISMATCH, "progress": 0}
	if attempt_midi.is_empty():
		return {"result": Result.IN_PROGRESS, "progress": 0}
	if attempt_midi.size() > target_midi.size():
		return {"result": Result.MISMATCH, "progress": 0}

	if not r["order_matters"]:
		return _evaluate_unordered(target_midi, attempt_midi, r)
	if r["allow_transposition"]:
		return _evaluate_transposed(target_midi, attempt_midi, r)
	return _evaluate_ordered(target_midi, attempt_midi, r)


## Convenience wrapper taking note names instead of MIDI numbers.
static func evaluate_names(target_names: Array, attempt_names: Array, rules: Dictionary = {}) -> Dictionary:
	return evaluate(
		NoteNames.list_to_midi(target_names),
		NoteNames.list_to_midi(attempt_names),
		rules
	)


static func _evaluate_ordered(target: Array, attempt: Array, r: Dictionary) -> Dictionary:
	for i in attempt.size():
		if not _same_pitch(target[i], attempt[i], r["octave_matters"]):
			return {"result": Result.MISMATCH, "progress": i}
	return {
		"result": Result.MATCH if attempt.size() == target.size() else Result.IN_PROGRESS,
		"progress": attempt.size(),
	}


## Order-free: the attempt must be a sub-multiset of the target.
## Used for doors that want the right notes but not a specific tune.
static func _evaluate_unordered(target: Array, attempt: Array, r: Dictionary) -> Dictionary:
	var remaining := _normalized(target, r["octave_matters"])
	var matched := 0
	for note in _normalized(attempt, r["octave_matters"]):
		var idx := remaining.find(note)
		if idx == -1:
			return {"result": Result.MISMATCH, "progress": matched}
		remaining.remove_at(idx)
		matched += 1
	return {
		"result": Result.MATCH if matched == target.size() else Result.IN_PROGRESS,
		"progress": matched,
	}


## Transposition-tolerant: compares the shape (interval sequence), not the
## absolute pitches. "Play this phrase in any key."
static func _evaluate_transposed(target: Array, attempt: Array, _r: Dictionary) -> Dictionary:
	# A single note has no interval to compare, so any pitch is a valid start.
	if attempt.size() == 1:
		return {
			"result": Result.MATCH if target.size() == 1 else Result.IN_PROGRESS,
			"progress": 1,
		}
	for i in range(1, attempt.size()):
		if attempt[i] - attempt[i - 1] != target[i] - target[i - 1]:
			return {"result": Result.MISMATCH, "progress": i - 1}
	return {
		"result": Result.MATCH if attempt.size() == target.size() else Result.IN_PROGRESS,
		"progress": attempt.size(),
	}


static func _same_pitch(a: int, b: int, octave_matters: bool) -> bool:
	if octave_matters:
		return a == b
	return NoteNames.pitch_class(a) == NoteNames.pitch_class(b)


static func _normalized(notes: Array, octave_matters: bool) -> Array[int]:
	var out: Array[int] = []
	for n in notes:
		out.append(int(n) if octave_matters else NoteNames.pitch_class(int(n)))
	return out


static func _merged_rules(rules: Dictionary) -> Dictionary:
	var merged := DEFAULT_RULES.duplicate()
	for key in rules:
		merged[key] = rules[key]
	return merged
