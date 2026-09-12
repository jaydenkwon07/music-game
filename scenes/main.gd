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
