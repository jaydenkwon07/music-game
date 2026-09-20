class_name DoorArt
extends Node2D
## The drawn body of a melody-locked door (M5 Step 5b), extracted from Door like DoorGems
## so Door stays a controller. A carved stone jamb + lintel frame a brass ORGAN-PIPE leaf:
## the "resonant architecture" of §4.7 — warm brass against cold stone, so a door reads as a
## barrier, not a gap, at a glance. Drawn FLAT (form, not lighting — the PointLights light it,
## §4.7/§8a); colours by EnvPalette name (§3). Every point goes through the (across, depth)
## frame DoorLayout defines, so ONE path draws both the N (vertical) and E (horizontal) doors.

## Stone border along the opening's sides, and the stone beam at the wall end.
@export var jamb_thickness: float = 8.0
@export var lintel_thickness: float = 10.0
## How many brass pipes fill the leaf, and the darker groove between them.
@export var pipe_count: int = 6
@export var groove_width: float = 2.0
## How much the pipe tops (wall end) vary in height — the organ-pipe read.
@export var cap_variation: float = 16.0

# A fixed, pleasant up-down pattern for pipe-top heights (0 = tall, 1 = short). Deterministic
# by pipe index, never RNG — a room re-instances identically (§5).
const _CAP_PATTERN := [0.15, 0.6, 0.0, 0.45, 0.2, 0.7, 0.35, 0.55]

var _facing: Vector2i = Vector2i(0, 1)
var _slab: Vector2 = Vector2(72.0, 90.0)
var _open: bool = false


func configure(facing: Vector2i, slab_size: Vector2) -> void:
	_facing = facing
	_slab = slab_size
	queue_redraw()


func set_open(open: bool) -> void:
	_open = open
	queue_redraw()


# A point in the (across, depth) frame: `ac` runs along the opening, `dp` into the room
# (dp = +half_depth is the room-facing edge, −half_depth the wall end).
func _pt(ac: float, dp: float) -> Vector2:
	return DoorLayout.across(_facing) * ac + Vector2(_facing) * dp


func _rect(a0: float, a1: float, d0: float, d1: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		_pt(a0, d0), _pt(a1, d0), _pt(a1, d1), _pt(a0, d1),
	]), col)


# A frame stone: filled rock_mid with a 2px rock_high rim, so it reads as cut, not natural
# rock. Drawn per piece (not one full slab) so the OPENING between the pieces stays unpainted.
func _stone(a0: float, a1: float, d0: float, d1: float) -> void:
	_rect(a0, a1, d0, d1, EnvPalette.color("rock_high"))                     # bright cut edge…
	_rect(a0 + 2.0, a1 - 2.0, d0 + 2.0, d1 - 2.0, EnvPalette.color("rock_mid"))  # …face inset back


func _draw() -> void:
	var half_a := DoorLayout.across_extent(_facing, _slab) * 0.5
	var half_d := DoorLayout.depth_extent(_facing, _slab) * 0.5
	var oa := half_a - jamb_thickness
	var wall_d := -half_d + lintel_thickness
	if oa <= 0.0:
		_rect(-half_a, half_a, -half_d, half_d, EnvPalette.color("rock_mid"))
		return

	if _open:
		# Leaf retracted: draw the stone as a BORDER (two jambs + a lintel) and leave the opening
		# unpainted, so the room's own floor shows straight through it — a passage, not the flat
		# black fill a full slab left behind. A soft shadow just under the lintel keeps it reading
		# as a doorway receding into the passage.
		_stone(-half_a, -oa, -half_d, half_d)   # left jamb (full depth)
		_stone(oa, half_a, -half_d, half_d)     # right jamb
		_stone(-oa, oa, -half_d, wall_d)        # lintel at the wall end
		_rect(-oa, oa, wall_d, wall_d + 5.0, EnvPalette.with_alpha("rock_void", 0.55))
		return

	# Closed: a carved stone slab (a lighter rim so it reads as cut, not natural rock)…
	_rect(-half_a, half_a, -half_d, half_d, EnvPalette.color("rock_mid"))
	_rect(-half_a, half_a, -half_d, half_d, EnvPalette.color("rock_high"))  # rim…
	_rect(-half_a + 2.0, half_a - 2.0, -half_d + 2.0, half_d - 2.0, EnvPalette.color("rock_mid"))  # …inset back
	# …with a dark recess behind the brass organ pipes that fill the opening.
	_rect(-oa, oa, wall_d, half_d, EnvPalette.color("rock_void"))
	var slot := (2.0 * oa) / float(maxi(pipe_count, 1))
	for i in pipe_count:
		var a0 := -oa + float(i) * slot + groove_width * 0.5
		var a1 := -oa + float(i + 1) * slot - groove_width * 0.5
		var top := wall_d + cap_variation * float(_CAP_PATTERN[i % _CAP_PATTERN.size()])
		_rect(a0, a1, top, half_d, EnvPalette.color("brass"))
		_rect(a0, a1, top, top + 2.0, EnvPalette.color("copper"))  # a lit brass cap edge
