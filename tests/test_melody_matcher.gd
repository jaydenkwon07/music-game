extends SceneTree
## Unit tests for the pure music seam. No nodes, no scenes, no engine state.
##
## Run:  godot --headless --script tests/test_melody_matcher.gd
##
## These cover the logic that decides whether a door opens. If this file is
## green, every door in the game behaves correctly regardless of level design.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_note_names()
	test_ordered_match()
	test_partial_progress()
	test_octave_tolerance()
	test_unordered_match()
	test_transposition()
	test_malformed_input()

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func test_note_names() -> void:
	check(NoteNames.to_midi("C4") == 60, "C4 is MIDI 60")
	check(NoteNames.to_midi("A4") == 69, "A4 is MIDI 69")
	check(NoteNames.to_midi("F#3") == 54, "F#3 is MIDI 54")
	check(NoteNames.to_midi("Bb2") == 46, "Bb2 is MIDI 46")
	check(NoteNames.to_name(60) == "C4", "60 spells back to C4")
	check(NoteNames.pitch_class(72) == NoteNames.pitch_class(60), "C4 and C5 share a pitch class")


func test_ordered_match() -> void:
	var target := NoteNames.list_to_midi(["C4", "E4", "G4", "C5"])

	var exact := MelodyMatcher.evaluate(target, target)
	check(exact["result"] == MelodyMatcher.Result.MATCH, "exact sequence matches")

	var scrambled := NoteNames.list_to_midi(["E4", "C4", "G4", "C5"])
	var out := MelodyMatcher.evaluate(target, scrambled)
	check(out["result"] == MelodyMatcher.Result.MISMATCH, "wrong order fails when order matters")


func test_partial_progress() -> void:
	var target := NoteNames.list_to_midi(["C4", "E4", "G4", "C5"])

	var two := MelodyMatcher.evaluate(target, NoteNames.list_to_midi(["C4", "E4"]))
	check(two["result"] == MelodyMatcher.Result.IN_PROGRESS, "correct prefix is in progress")
	check(two["progress"] == 2, "progress counts confirmed notes")

	var broken := MelodyMatcher.evaluate(target, NoteNames.list_to_midi(["C4", "F4"]))
	check(broken["result"] == MelodyMatcher.Result.MISMATCH, "wrong third note fails")
	check(broken["progress"] == 1, "progress reports how far the player got")

	var overlong := MelodyMatcher.evaluate(target, NoteNames.list_to_midi(["C4", "E4", "G4", "C5", "C5"]))
	check(overlong["result"] == MelodyMatcher.Result.MISMATCH, "too many notes fails")


func test_octave_tolerance() -> void:
	var target := NoteNames.list_to_midi(["C4", "E4"])
	var up_an_octave := NoteNames.list_to_midi(["C5", "E5"])

	var loose := MelodyMatcher.evaluate(target, up_an_octave, {"octave_matters": false})
	check(loose["result"] == MelodyMatcher.Result.MATCH, "octave ignored by default")

	var strict := MelodyMatcher.evaluate(target, up_an_octave, {"octave_matters": true})
	check(strict["result"] == MelodyMatcher.Result.MISMATCH, "octave enforced when asked")


func test_unordered_match() -> void:
	var target := NoteNames.list_to_midi(["C4", "E4", "G4"])
	var rules := {"order_matters": false}

	var scrambled := NoteNames.list_to_midi(["G4", "C4", "E4"])
	check(
		MelodyMatcher.evaluate(target, scrambled, rules)["result"] == MelodyMatcher.Result.MATCH,
		"any order matches when order does not matter"
	)

	var repeated := NoteNames.list_to_midi(["C4", "C4"])
	check(
		MelodyMatcher.evaluate(target, repeated, rules)["result"] == MelodyMatcher.Result.MISMATCH,
		"a note cannot be reused beyond its count in the target"
	)


func test_transposition() -> void:
	var target := NoteNames.list_to_midi(["C4", "E4", "G4"])
	var rules := {"allow_transposition": true, "octave_matters": true}

	var up_a_fifth := NoteNames.list_to_midi(["G4", "B4", "D5"])
	check(
		MelodyMatcher.evaluate(target, up_a_fifth, rules)["result"] == MelodyMatcher.Result.MATCH,
		"same shape in another key matches"
	)

	var wrong_shape := NoteNames.list_to_midi(["G4", "A4", "D5"])
	check(
		MelodyMatcher.evaluate(target, wrong_shape, rules)["result"] == MelodyMatcher.Result.MISMATCH,
		"different intervals fail even when transposition is allowed"
	)


func test_malformed_input() -> void:
	check(NoteNames.to_midi("wobble") == -1, "garbage note name returns -1")
	check(NoteNames.to_midi("") == -1, "empty note name returns -1")
	check(
		MelodyMatcher.evaluate([], [60])["result"] == MelodyMatcher.Result.MISMATCH,
		"empty target never matches"
	)
	check(
		MelodyMatcher.evaluate([60], [])["result"] == MelodyMatcher.Result.IN_PROGRESS,
		"empty attempt is in progress, not a failure"
	)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
