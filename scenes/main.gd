extends Node2D
## Entry point. Places the player in the test room and shows a small debug
## readout so M0 is verifiable at a glance.

@onready var room: Node2D = $TestRoom
@onready var player: CharacterBody2D = $Player
@onready var debug_label: Label = $UI/DebugLabel


func _ready() -> void:
	player.position = room.spawn_point()
	_verify_seam()
	_spawn_resonators()
	_spawn_pickups()
	_spawn_doors()
	add_child(InstrumentOverlay.new())


## Drops the two M2 doors (§7 Step 3): a 1-note first door and a 3-note ordered
## door, so the length ramp and gem count are both visible. Scaffolding like the
## resonators — real doors get placed in real rooms at M3. Each references only a
## melody id; the melody (and its gem count) is pure data.
func _spawn_doors() -> void:
	var placements := {"door_test_01": Vector2(120, 50), "door_test_02": Vector2(400, 50)}
	for melody_id: String in placements:
		var door := Door.new()
		door.melody_id = melody_id
		door.position = placements[melody_id]
		add_child(door)


## Drops the three M2 notes in the room to be collected (§7 Step 1). The player
## starts empty, so these are the only way to gain anything playable. One per
## category, so collecting visibly changes the note bar's colours. Scaffolding,
## like the resonators — real pickups get placed in real rooms at M3.
func _spawn_pickups() -> void:
	var placements := {"n_break": Vector2(180, 120), "n_mend": Vector2(240, 120), "n_step": Vector2(300, 120)}
	for note_id: String in placements:
		var pickup := NotePickup.new()
		pickup.note_id = note_id
		pickup.position = placements[note_id]
		add_child(pickup)


## Drops a few resonators in the gray box so M1 can test the note -> world
## response. Scaffolding, like the room itself: real objects get placed in real
## rooms at M3. Each is tuned to a palette slot, not a pitch.
func _spawn_resonators() -> void:
	var placements := {0: Vector2(180, 90), 2: Vector2(240, 78), 4: Vector2(300, 90)}
	for slot: int in placements:
		var r := Resonator.new()
		r.slot = slot
		r.position = placements[slot]
		add_child(r)


func _process(_delta: float) -> void:
	debug_label.text = "%d x %d   layout: %s   speed: %d" % [
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		InputConfig.Layout.keys()[InputConfig.current_layout],
		roundi(player.velocity.length()),
	]


func _unhandled_input(event: InputEvent) -> void:
	# Tab swaps movement layout. Temporary, until there is a settings menu.
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		var next := (
			InputConfig.Layout.ARROWS
			if InputConfig.current_layout == InputConfig.Layout.WASD
			else InputConfig.Layout.WASD
		)
		InputConfig.apply_layout(next)


## Proves the data seam works before anything depends on it: load a melody
## from JSON, match a correct and an incorrect attempt against it, print both.
## Delete this once M2 exercises the same path for real.
func _verify_seam() -> void:
	var ids := MelodyLibrary.get_ids()
	if ids.is_empty():
		print("Seam check: no melodies loaded.")
		return

	var id: String = ids[0]
	var target := MelodyLibrary.get_midi(id)
	var rules := MelodyLibrary.get_rules(id)

	var right := MelodyMatcher.evaluate(target, target, rules)
	var wrong := MelodyMatcher.evaluate(target, [target[0], target[0]], rules)

	print("Seam check '%s': correct -> %s, wrong -> %s" % [
		id,
		MelodyMatcher.Result.keys()[right["result"]],
		MelodyMatcher.Result.keys()[wrong["result"]],
	])
