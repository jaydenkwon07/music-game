extends SceneTree
## Unit tests for InstrumentKeyboardLayout — the pure one-octave piano geometry
## behind the instrument-state keyboard widget (§4 pure seam, §10). No nodes, no
## scenes, no engine state.
##
## Run:  godot --headless --script tests/test_instrument_keyboard_layout.gd
##
## The widget itself is presentational and verified by the owner on a real run;
## this pins the geometry it draws — key counts, the piano shape, and the real
## gaps at E-F and B-C.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_key_counts()
	test_white_row_is_evenly_spaced()
	test_blacks_sit_between_their_whites()
	test_no_black_at_ef_and_bc_gaps()
	test_row_width()

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func test_key_counts() -> void:
	var slots := InstrumentKeyboardLayout.slots(10.0, 1.0, 24.0, 14.0)
	check(slots.size() == 12, "one octave is twelve slots (the collectible set, §6)")
	var whites := 0
	var blacks := 0
	for s in slots:
		if s["white"]:
			whites += 1
		else:
			blacks += 1
	check(whites == 7, "seven white keys")
	check(blacks == 5, "five black keys")


func test_white_row_is_evenly_spaced() -> void:
	# Whites are a plain row: each starts one (width + gap) after the previous.
	var slots := InstrumentKeyboardLayout.slots(10.0, 1.0, 24.0, 14.0)
	var xs: Array = []
	for s in slots:
		if s["white"]:
			xs.append((s["rect"] as Rect2).position.x)
	for i in range(1, xs.size()):
		check(is_equal_approx(xs[i] - xs[i - 1], 11.0), "white %d sits one step right of %d" % [i, i - 1])


func test_blacks_sit_between_their_whites() -> void:
	# Each black key's centre falls between the right edge of its left white and
	# the left edge of its right white.
	var slots := InstrumentKeyboardLayout.slots(10.0, 1.0, 24.0, 14.0)
	var white_by_semitone := {}
	for s in slots:
		if s["white"]:
			white_by_semitone[s["semitone"]] = (s["rect"] as Rect2)
	for s in slots:
		if s["white"]:
			continue
		var semitone: int = s["semitone"]
		var left: Rect2 = white_by_semitone[semitone - 1]
		var right: Rect2 = white_by_semitone[semitone + 1]
		var centre := (s["rect"] as Rect2).get_center().x
		check(
			centre > left.position.x and centre < right.end.x,
			"black %d sits between its neighbouring whites" % semitone
		)


func test_no_black_at_ef_and_bc_gaps() -> void:
	# The self-teaching gaps (§6): no black key at semitone 5 (E->F) or 0/12
	# boundary (B->C). i.e. semitones 4 and 5 are adjacent whites, as are 11 and 0.
	var slots := InstrumentKeyboardLayout.slots(10.0, 1.0, 24.0, 14.0)
	for s in slots:
		if s["semitone"] == 4 or s["semitone"] == 5 or s["semitone"] == 11 or s["semitone"] == 0:
			check(s["white"], "semitone %d is a white key (gap edge)" % s["semitone"])
	# And there is genuinely no black slot in those gaps.
	var black_semitones := []
	for s in slots:
		if not s["white"]:
			black_semitones.append(s["semitone"])
	check(not black_semitones.has(5), "no black key at the E-F gap")
	check(black_semitones.has(1) and black_semitones.has(3), "blacks exist where they should (C#, D#)")


func test_row_width() -> void:
	# Seven whites of 10 with six 1px gaps = 76.
	check(
		is_equal_approx(InstrumentKeyboardLayout.row_width(10.0, 1.0), 76.0),
		"row width is 7 keys plus 6 gaps"
	)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
