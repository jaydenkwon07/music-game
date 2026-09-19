class_name Door
extends Interactable
## A melody-locked door (§5.10, §6.6). Configured with only a melody id (§3); it
## composes a MelodyLock and a DoorGems row that shows the melody's STRUCTURE — how
## many notes, their categories, and progress so far — at top-down scale. It never
## shows which notes: the gems tint by category only (D-M3-3), and the specific
## melody is learned from a MelodyChime in the world (§6.5). It gates a real room
## exit — opening disables its blocking body so the RoomLink behind it is reachable.
##
## Interacting (space, via the Interactor) enters the instrument state and arms the
## lock. Play the melody: gems light one at a time; a wrong note resets them with a
## soft cue and no penalty (§6); the full melody triggers the unlock choreography
## (§9) and opens the door for good.

@export var melody_id: String = ""
## Sizes doubled from M3 in the §4 resolution migration (world units doubled).
@export var slab_size: Vector2 = Vector2(48.0, 60.0)
## Unlock choreography, the loop's payoff (§9). All tunable by feel (§10): a held
## beat, gems flaring one at a time as each note re-sounds (an arpeggio resolving),
## a camera shake, and a dust burst.
@export var unlock_hold: float = 0.15         ## beat held before and after the flare
@export var unlock_note_gap: float = 0.12     ## seconds per flared gem / replayed note
@export var unlock_shake_strength: float = 4.0
@export var unlock_shake_time: float = 0.35
@export var unlock_dust_count: int = 16

## Gems show a note's CATEGORY, not the note itself (D-M3-3): every gem in a
## category uses this one representative index within the category's hue arc. Lives
## here (not on DoorGems) because the keyboard's melody strip references it too, so
## the door, its gems and the strip all speak one colour language.
const CATEGORY_REP_INDEX := 1

var _lock: MelodyLock
var _gems: DoorGems
var _targets: Array = []
var _total: int = 0
var _open: bool = false
var _blocker: CollisionShape2D


func _ready() -> void:
	# Reach past the slab so the player, stopped at the door's edge, is still in
	# interact range.
	radius = maxf(radius, slab_size.length())
	super._ready()

	_lock = MelodyLock.new()
	_lock.melody_id = melody_id
	add_child(_lock)
	_lock.unlocked.connect(_on_unlocked)
	_lock.progress_changed.connect(_on_progress)
	_lock.mismatch.connect(_on_mismatch)
	_total = _lock.total()
	_targets = _lock.target_midi()

	_add_blocker()
	_gems = DoorGems.new()
	add_child(_gems)
	_gems.configure(_targets, slab_size)
	NoteBus.instrument_state_changed.connect(_on_instrument_state_changed)

	# Rooms are re-instanced on every transition (§6.3a); a door the player already
	# opened must come back open, or the required return to Room A shows it locked
	# again. WorldState remembers this, keyed by melody id.
	if WorldState.is_door_open(melody_id):
		_open_immediately()


## A closed door blocks; interacting is pointless once it is open.
func can_interact() -> bool:
	return not _open


func interact(_player: Node2D) -> void:
	if _open or NoteBus.instrument_state_active:
		return
	# The real entry the Interactor's temporary fallback stood in for: enter the
	# instrument state and start listening on THIS door's melody.
	NoteBus.set_instrument_state(true)
	_lock.arm()


## The instrument state ended — either the player cancelled/exited (via the
## Interactor) or this door just opened. Either way stop listening and clear the
## gems; if we opened, the open visual takes over.
func _on_instrument_state_changed(active: bool) -> void:
	if active:
		return
	_lock.disarm()
	_gems.set_progress(0, _total)


func _on_progress(progress: int, total: int) -> void:
	_total = total
	_gems.set_progress(progress, total)


func _on_mismatch() -> void:
	_gems.mismatch()


## The melody matched — play the payoff (§9), then open. Runs while still in the
## instrument state, so movement stays suspended through the moment. Async: each
## await yields, the last step finalises the open.
func _on_unlocked() -> void:
	if _open:
		return
	_open = true                 # can_interact() is false from here on
	# Disarm before replaying the melody so the arpeggio's own notes can't re-enter
	# matching (the lock also disarms itself on MATCH; this is belt-and-braces).
	_lock.disarm()

	await get_tree().create_timer(unlock_hold).timeout
	NoteBus.request_shake(unlock_shake_strength, unlock_shake_time)
	_spawn_dust()

	# Flare the gems one at a time, re-sounding each note as it lights — the melody
	# resolves as the door gives way.
	_gems.flare(0)
	for i in _total:
		_gems.flare(i + 1)
		if i < _targets.size():
			NoteBus.play_note(int(_targets[i]), global_position)
		await get_tree().create_timer(unlock_note_gap).timeout

	await get_tree().create_timer(unlock_hold).timeout
	_finalize_open()


## Commit the open: stop blocking, remember it across transitions, darken the gems,
## and leave the instrument state.
func _finalize_open() -> void:
	if _blocker != null:
		_blocker.set_deferred("disabled", true)
	WorldState.mark_door_open(melody_id)
	_gems.set_open(true)
	NoteBus.set_instrument_state(false)
	queue_redraw()


## A puff of stone dust at the gem row as the door gives way (§9). Parented to the
## door (which is not freed), coloured stone so it reads as rock, not a note.
func _spawn_dust() -> void:
	var dust := ParticleBurst.burst(EnvPalette.color("rock_high"))
	dust.count = unlock_dust_count
	add_child(dust)
	dust.position = Vector2(0.0, -slab_size.y * 0.5)


## Start open with no instrument-state round trip — used when WorldState says this
## door was opened on an earlier visit to the room.
func _open_immediately() -> void:
	_open = true
	if _blocker != null:
		_blocker.set_deferred("disabled", true)
	_gems.set_open(true)
	queue_redraw()


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	_blocker = CollisionShape2D.new()
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)


func _draw() -> void:
	var rect := Rect2(-slab_size * 0.5, slab_size)
	if _open:
		# Hollow frame: the slab has swung away, leaving void the light can't reach.
		draw_rect(rect, EnvPalette.color("rock_void"), false, 1.0)
	else:
		draw_rect(rect, EnvPalette.color("rock_deep"), true)
		draw_rect(rect, EnvPalette.with_alpha("ink", 0.5), false, 1.0)
