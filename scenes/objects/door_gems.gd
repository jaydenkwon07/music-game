class_name DoorGems
extends Node2D
## The gem row on a melody-locked door (extracted from Door at M4 Step 6 to keep
## Door focused). One gem per melody note, drawn just above the slab: it reveals
## the melody's STRUCTURE — how many notes, their categories, progress so far —
## and never which notes (D-M3-3). Each gem is a drawn circle plus a small
## PointLight2D in its category colour (§5.2), dim until confirmed, so the door
## announces itself in the dark (§5.4). Colour resolves through NoteRegistry →
## NoteColors; nothing here is authored (§3).
##
## A child of the Door at its origin, so gem coordinates share the door's space.
## Category colour uses Door.CATEGORY_REP_INDEX, the same index the keyboard's
## melody strip uses, so door and strip speak one colour language.

@export var gem_radius: float = 8.0
@export var gem_margin: float = 15.0        ## how far above the slab the row sits
@export var gem_light_radius: float = 38.0
@export var gem_light_energy: float = 0.4
@export var gem_light_lit_energy: float = 0.9
## Seconds the soft mismatch cue (a dip of the whole row) lasts.
@export var mismatch_time: float = 0.35

var _targets: Array = []
var _total: int = 0
var _progress: int = 0
var _open: bool = false
var _mismatch_flash: float = 0.0      # remaining mismatch-cue time, seconds
var _slab_size: Vector2 = Vector2.ZERO
var _facing: Vector2i = Vector2i(0, 1)  # room-facing direction; the bar sits on this side
var _gem_lights: Array[PointLight2D] = []


## Build the gem row for a melody's target MIDI, on the ROOM-facing side of the slab (M5
## Step 5b: N→below, E→left, from `facing`). Call once, after adding this node to the door.
func configure(targets: Array, slab_size: Vector2, facing: Vector2i) -> void:
	_targets = targets
	_total = targets.size()
	_slab_size = slab_size
	_facing = facing
	_build_gem_lights()
	queue_redraw()


func set_progress(progress: int, total: int) -> void:
	_progress = progress
	_total = total
	_update_gem_lights()
	queue_redraw()


func mismatch() -> void:
	_mismatch_flash = mismatch_time
	_update_gem_lights()
	set_process(true)
	queue_redraw()


## The door opened: every gem stays LIT and keeps drawing — an opened door is a landmark (5d),
## not a dark hole. Together with the door's persistent brass frame light, the solved door
## remains one of the brightest things in the room, restored whenever the room re-instances.
func set_open(open: bool) -> void:
	_open = open
	_update_gem_lights()
	queue_redraw()


## Light exactly the first `lit` gems at full brightness, the rest dim — the unlock
## choreography flares them one at a time (§9). Independent of match progress.
func flare(lit: int) -> void:
	_progress = clampi(lit, 0, _total)
	for i in _gem_lights.size():
		_gem_lights[i].energy = gem_light_lit_energy if i < _progress else gem_light_energy
	queue_redraw()


func _process(delta: float) -> void:
	if _mismatch_flash > 0.0:
		_mismatch_flash = maxf(_mismatch_flash - delta, 0.0)
		if _mismatch_flash == 0.0:
			_update_gem_lights()  # flash over — gems return to their lit/dim state
		queue_redraw()
	else:
		set_process(false)


# --- Lights ---

## One light per gem, positioned to match the drawn gem and coloured by that gem's
## category (§5.2). Built once; energy is what changes as the lock advances.
func _build_gem_lights() -> void:
	for i in _total:
		var col := _gem_category_color(int(_targets[i]) if i < _targets.size() else -1)
		var light := Lighting.make_light(gem_light_radius, gem_light_energy, col, false)
		light.position = _gem_position(i)
		add_child(light)
		_gem_lights.append(light)
	_update_gem_lights()


## Brighten confirmed gems, dim the rest, dip the whole row on a mismatch, and go
## dark once the door is open (the gems stop drawing then too).
func _update_gem_lights() -> void:
	var flashing := _mismatch_flash > 0.0
	for i in _gem_lights.size():
		var energy := gem_light_energy
		if _open:
			energy = gem_light_lit_energy   # opened door: all gems stay lit — a landmark (5d)
		elif flashing:
			energy = gem_light_energy * 0.4
		elif i < _progress:
			energy = gem_light_lit_energy
		_gem_lights[i].energy = energy


# --- Geometry & drawing ---

func _spacing() -> float:
	return gem_radius * 2.0 + 6.0


## Gem i's local position, shared by the drawn gem and its light so they align. Laid out on
## the room-facing side and along the opening via DoorLayout, so N and E orient correctly.
func _gem_position(i: int) -> Vector2:
	return DoorLayout.gem_position(i, _total, _facing, _slab_size, gem_margin, _spacing())


func _draw() -> void:
	if _total <= 0:
		return
	var flashing := _mismatch_flash > 0.0
	for i in _total:
		var base := _gem_category_color(int(_targets[i]) if i < _targets.size() else -1)
		var col: Color
		if _open:
			col = base                      # opened door: every gem lit — a landmark (5d)
		elif flashing:
			# Soft "no": the whole row falls to a dull desaturated stone grey briefly.
			col = base.darkened(0.6).lerp(EnvPalette.color("rock_high"), 0.7)
		elif i < _progress:
			col = base                      # lit: confirmed
		else:
			col = base.darkened(0.6)        # dim, but the target colour still reads
		var pos := _gem_position(i)
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
	return NoteColors.color(note["category"], Door.CATEGORY_REP_INDEX, octave)
