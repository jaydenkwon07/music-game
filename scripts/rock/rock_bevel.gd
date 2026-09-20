class_name RockBevel
extends RefCounted
## Pure corner-bevel geometry for the cave tileset (M5 Step 2c). No nodes, no signals,
## no autoloads — the same pure-seam contract as the music helpers (CLAUDE.md §4), so
## the sign conventions below are unit-testable without booting the engine or its
## palette. RockTileSet owns how a tile LOOKS (colour, seam); this owns only the shape
## maths, so the two can be reasoned about, and tested, apart.
##
## A rock corner is cut on a 45° line so a diagonal run of tiles reads as a slope, not a
## staircase. Convex (outer) corners — both adjacent sides face floor — get one leg
## length; concave (inner) corners — both sides rock but the diagonal is floor — get
## another. The leg is a fraction of the cell; equal legs keep every cut at 45°.

## The 45° line is at unit slope, so a pixel's perpendicular distance to it is the
## along-axis offset divided by sqrt(2).
const SQRT2 := 1.4142135623730951

# Which cardinal / diagonal neighbours are rock, as bitmasks. These are the single
# source of truth for the neighbourhood semantics; RockTileSet aliases them so its
# blob configs and peering bits cannot drift from what the bevel reads.
const S_TOP := 1
const S_RIGHT := 2
const S_BOTTOM := 4
const S_LEFT := 8
const C_TR := 1
const C_BR := 2
const C_BL := 4
const C_TL := 8

# Corner ids. Order matches the C_* corners so a cut and its seam always agree.
const CORNER_TR := 0
const CORNER_BR := 1
const CORNER_BL := 2
const CORNER_TL := 3


## The bevels active on a tile, as [corner_id, leg_px]. A corner is convex when both its
## adjacent sides face floor, concave when both are rock but the diagonal is floor;
## each kind takes its own fraction of the cell. A fraction of 0 (the default for
## concave) drops that kind, so it contributes neither a cut nor a seam.
static func active(sides: int, corners: int, tp: int, convex_frac: float, concave_frac: float) -> Array:
	var lc := convex_frac * float(tp)
	var lk := concave_frac * float(tp)
	var out: Array = []
	_add(out, CORNER_TR, (sides & S_TOP) == 0 and (sides & S_RIGHT) == 0,
		(sides & S_TOP) != 0 and (sides & S_RIGHT) != 0 and (corners & C_TR) == 0, lc, lk)
	_add(out, CORNER_BR, (sides & S_BOTTOM) == 0 and (sides & S_RIGHT) == 0,
		(sides & S_BOTTOM) != 0 and (sides & S_RIGHT) != 0 and (corners & C_BR) == 0, lc, lk)
	_add(out, CORNER_BL, (sides & S_BOTTOM) == 0 and (sides & S_LEFT) == 0,
		(sides & S_BOTTOM) != 0 and (sides & S_LEFT) != 0 and (corners & C_BL) == 0, lc, lk)
	_add(out, CORNER_TL, (sides & S_TOP) == 0 and (sides & S_LEFT) == 0,
		(sides & S_TOP) != 0 and (sides & S_LEFT) != 0 and (corners & C_TL) == 0, lc, lk)
	return out


static func _add(out: Array, corner: int, convex: bool, concave: bool, lc: float, lk: float) -> void:
	if convex and lc > 0.0:
		out.append([corner, lc])
	elif concave and lk > 0.0:
		out.append([corner, lk])


## Signed perpendicular distance (px) from a point to a corner's 45° bevel line. A
## positive result means the point lies in the cut triangle (outside the rock); a
## negative one gives its distance on the rock side, for the contact seam. The two tile
## edges meeting at the corner bound the cut to that corner's triangle, so a cut never
## leaks across the tile and no extra clamping is needed. Takes floats so the same
## function serves both the per-pixel fill and the collision-polygon clip.
static func corner_signed(x: float, y: float, tp: int, leg: float, corner: int) -> float:
	var s := 0.0
	if corner == CORNER_TR:
		s = (x - y) - (float(tp) - leg)
	elif corner == CORNER_BR:
		s = (x + y) - (2.0 * float(tp) - leg)
	elif corner == CORNER_BL:
		s = (y - x) - (float(tp) - leg)
	else:  # CORNER_TL
		s = leg - (x + y)
	return s / SQRT2


## The tile's silhouette as a collision/occluder polygon, in tile-centred coordinates
## (origin at the tile centre, ±tp/2), matching the drawn pixels exactly: the full
## square with every active corner sliced off on its 45° line. Built by clipping the
## square against each cut (keep the rock side), so it is correct for any legs — one
## sliced corner gives a triangle, an untouched tile the full square, a lone outcrop an
## octagon. Fewer than three points (a corner cut away to nothing) means no solid is
## left; the caller then gives that tile no collision, matching a silhouette that has
## itself all but vanished.
static func tile_polygon(sides: int, corners: int, tp: int, convex_frac: float, concave_frac: float) -> PackedVector2Array:
	var f := float(tp)
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(f, 0.0), Vector2(f, f), Vector2(0.0, f)])
	for b in active(sides, corners, tp, convex_frac, concave_frac):
		poly = _clip_to_rock(poly, tp, b[1], b[0])
		if poly.size() < 3:
			return PackedVector2Array()
	var h := f * 0.5
	var out := PackedVector2Array()
	for p in poly:
		var c := p - Vector2(h, h)
		if out.is_empty() or not out[out.size() - 1].is_equal_approx(c):
			out.append(c)
	if out.size() >= 2 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out if out.size() >= 3 else PackedVector2Array()


## Sutherland–Hodgman clip of a convex polygon against one corner's bevel line, keeping
## the rock side (signed <= 0). corner_signed is linear, so an edge's crossing point is
## a plain interpolation of its endpoints' signed values.
static func _clip_to_rock(poly: PackedVector2Array, tp: int, leg: float, corner: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var sa := corner_signed(a.x, a.y, tp, leg, corner)
		var sb := corner_signed(b.x, b.y, tp, leg, corner)
		if sa <= 0.0:
			out.append(a)
		if (sa <= 0.0) != (sb <= 0.0):
			out.append(a + (b - a) * (sa / (sa - sb)))
	return out
