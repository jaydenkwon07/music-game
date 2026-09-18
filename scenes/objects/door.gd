class_name Door
extends Interactable
## A melody-locked door (§5.10, §6.6). Configured with only a melody id (§3); it
## composes a MelodyLock and shows the melody's STRUCTURE as gems — how many notes,
## their categories, and progress so far — at top-down scale. It never shows which
## notes: as of M3 the gems tint by category only (D-M3-3), and the specific melody
## is learned from a MelodyChime in the world (§6.5). It gates a real room exit —
## opening disables its blocking body so the RoomLink behind it is reachable (§3.7).
##
## Interacting (space, via the Interactor) enters the instrument state and arms the
## lock. Play the melody: gems light one at a time; a wrong note resets them with a
## soft cue and no penalty (§6); the full melody opens the door for good.

@export var melody_id: String = ""
## Sizes doubled from M3 in the §4 resolution migration (world units doubled).
@export var slab_size: Vector2 = Vector2(48.0, 60.0)
## Gem radius and how far above the slab the gem row sits, in pixels.
@export var gem_radius: float = 5.0
@export var gem_margin: float = 10.0
## Seconds the soft mismatch cue lasts.
@export var mismatch_time: float = 0.35
## Each gem carries a small light in its category colour (§5.2), dim until that
## gem is confirmed, so the door announces itself in the dark (§5.4).
@export var gem_light_radius: float = 25.0
@export var gem_light_energy: float = 0.4
@export var gem_light_lit_energy: float = 0.9

## Gems show a note's CATEGORY, not the note itself (D-M3-3): every gem in a
## category uses this one representative index within the category's hue arc, so
## the door reveals which categories are involved (structure) but never which
## specific note (content — that now lives on the chime, §6.5).
const CATEGORY_REP_INDEX := 1

var _lock: MelodyLock
var _targets: Array = []
var _progress: int = 0
var _total: int = 0
var _open: bool = false
var _mismatch_flash: float = 0.0  # remaining mismatch-cue time, seconds
var _blocker: CollisionShape2D
var _gem_lights: Array[PointLight2D] = []


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
	_build_gem_lights()
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
	_progress = 0
	_update_gem_lights()
	queue_redraw()


func _on_progress(progress: int, total: int) -> void:
	_progress = progress
	_total = total
	_update_gem_lights()
	queue_redraw()


func _on_mismatch() -> void:
	_mismatch_flash = mismatch_time
	_update_gem_lights()
	set_process(true)
	queue_redraw()


func _on_unlocked() -> void:
	_open = true
	# Stop blocking so the room behind the door becomes reachable.
	if _blocker != null:
		_blocker.set_deferred("disabled", true)
	# Remember it across transitions, so the return trip finds it open (§6.3a).
	WorldState.mark_door_open(melody_id)
	_update_gem_lights()
	NoteBus.set_instrument_state(false)
	queue_redraw()


## Start open with no instrument-state round trip — used when WorldState says this
## door was opened on an earlier visit to the room.
func _open_immediately() -> void:
	_open = true
	if _blocker != null:
		_blocker.set_deferred("disabled", true)
	_update_gem_lights()
	queue_redraw()


func _process(delta: float) -> void:
	if _mismatch_flash > 0.0:
		_mismatch_flash = maxf(_mismatch_flash - delta, 0.0)
		if _mismatch_flash == 0.0:
			_update_gem_lights()  # flash over — gems return to their lit/dim state
		queue_redraw()
	else:
		set_process(false)


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	_blocker = CollisionShape2D.new()
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)


## One light per gem, positioned to match the drawn gem row and coloured by that
## gem's category (§5.2). Built once; energy is what changes as the lock advances.
func _build_gem_lights() -> void:
	for i in _total:
		var col := _gem_category_color(int(_targets[i]) if i < _targets.size() else -1)
		var light := Lighting.make_light(gem_light_radius, gem_light_energy, col, false)
		light.position = _gem_position(i)
		add_child(light)
		_gem_lights.append(light)
	_update_gem_lights()


## Gem i's local position, shared by the drawn gem and its light so they align.
func _gem_position(i: int) -> Vector2:
	var spacing := gem_radius * 2.0 + 4.0
	var start_x := -_total * spacing * 0.5 + spacing * 0.5
	return Vector2(start_x + i * spacing, -slab_size.y * 0.5 - gem_margin)


## Brighten confirmed gems, dim the rest, dip the whole row on a mismatch, and go
## dark once the door is open (the gems stop drawing then too).
func _update_gem_lights() -> void:
	var flashing := _mismatch_flash > 0.0
	for i in _gem_lights.size():
		var energy := gem_light_energy
		if _open:
			energy = 0.0
		elif flashing:
			energy = gem_light_energy * 0.4
		elif i < _progress:
			energy = gem_light_lit_energy
		_gem_lights[i].energy = energy


func _draw() -> void:
	_draw_slab()
	_draw_gems()


func _draw_slab() -> void:
	var rect := Rect2(-slab_size * 0.5, slab_size)
	if _open:
		# Hollow frame: the slab has swung away, leaving void the light can't reach.
		draw_rect(rect, EnvPalette.color("rock_void"), false, 1.0)
	else:
		draw_rect(rect, EnvPalette.color("rock_deep"), true)
		draw_rect(rect, EnvPalette.with_alpha("ink", 0.5), false, 1.0)


func _draw_gems() -> void:
	if _total <= 0 or _open:
		return
	# One gem per melody note, centred in a row just above the slab.
	var spacing := gem_radius * 2.0 + 4.0
	var row_w := _total * spacing
	var start_x := -row_w * 0.5 + spacing * 0.5
	var y := -slab_size.y * 0.5 - gem_margin
	var flashing := _mismatch_flash > 0.0
	for i in _total:
		var base := _gem_category_color(int(_targets[i]) if i < _targets.size() else -1)
		var col: Color
		if flashing:
			# Soft "no": the whole row falls to a dull desaturated stone grey briefly.
			col = base.darkened(0.6).lerp(EnvPalette.color("rock_high"), 0.7)
		elif i < _progress:
			col = base                      # lit: confirmed
		else:
			col = base.darkened(0.6)        # dim, but the target colour still reads
		var pos := Vector2(start_x + i * spacing, y)
		draw_circle(pos, gem_radius, col)
		draw_arc(pos, gem_radius, 0.0, TAU, 16, EnvPalette.with_alpha("ink", 0.5), 1.0)


## The representative colour of a target note's CATEGORY (D-M3-3): resolve the
## note's category via NoteRegistry, then colour it at the category's fixed
## representative index — so the gem shows the family (warm / green / cool) and
## progress, never which of the four notes in that family it is. An unassigned
## pitch class falls back to NEUTRAL.
func _gem_category_color(midi: int) -> Color:
	var note := NoteRegistry.by_midi(midi)
	if note.is_empty():
		return NoteColors.NEUTRAL
	var octave := int(floor(float(midi) / 12.0)) - 1
	return NoteColors.color(note["category"], CATEGORY_REP_INDEX, octave)
