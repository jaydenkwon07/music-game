extends SceneTree
## Unit tests for the corner-bevel geometry (M5 Step 2c). No nodes, no scenes.
##
## Run:  godot --headless --script tests/test_rock_bevel.gd
##
## Targets RockBevel, the pure shape seam — deliberately NOT RockTileSet, which
## references the EnvPalette autoload and so cannot compile under --script. The bevel
## is a per-pixel 45° cut whose sign conventions are easy to get wrong and impossible
## to eyeball from a screenshot with confidence. This pins them: which pixels a corner
## cuts, that the cut is symmetric across corners, and that a corner is chosen as
## convex vs concave from the right rock/floor neighbourhood.

const TP := 30

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_convex_cut_region()
	test_leg_scales_the_cut()
	test_rock_side_distance()
	test_all_four_corners_symmetric()
	test_active_selection()
	test_collision_polygon()

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _cut(x: int, y: int, leg: float, corner: int) -> bool:
	return RockBevel.corner_signed(x, y, TP, leg, corner) > 0.0


func test_convex_cut_region() -> void:
	# A full-cell TR bevel is the diagonal x == y: everything above-right is cut.
	var full := float(TP)
	check(_cut(20, 5, full, RockBevel.CORNER_TR), "TR full bevel cuts the top-right pixels")
	check(not _cut(5, 20, full, RockBevel.CORNER_TR), "TR full bevel keeps the bottom-left pixels")
	check(not _cut(10, 10, full, RockBevel.CORNER_TR), "the diagonal itself is not cut")


func test_leg_scales_the_cut() -> void:
	# A shorter leg cuts a smaller corner: a pixel just inside the corner survives a
	# short bevel but not a full one.
	check(_cut(22, 8, float(TP), RockBevel.CORNER_TR), "(22,8) is cut at a full leg")
	check(not _cut(22, 8, 0.4 * TP, RockBevel.CORNER_TR), "(22,8) survives a short leg")
	# The very corner pixel is cut by any positive leg.
	check(_cut(TP - 1, 0, 0.2 * TP, RockBevel.CORNER_TR), "the corner pixel is cut even by a short leg")


func test_rock_side_distance() -> void:
	# On the rock side the signed value is negative and grows with distance from the
	# diagonal, so seam width can key off it. Full-cell TR line is x == y.
	var near := RockBevel.corner_signed(9, 10, TP, float(TP), RockBevel.CORNER_TR)
	var far := RockBevel.corner_signed(0, 20, TP, float(TP), RockBevel.CORNER_TR)
	check(near < 0.0 and far < 0.0, "rock-side pixels are negative")
	check(absf(far) > absf(near), "distance grows away from the bevel line")


func test_all_four_corners_symmetric() -> void:
	# Each corner cuts its own quadrant of the tile with a full-cell bevel: the pixel
	# nearest that corner is cut, the diagonally opposite one is not.
	check(_cut(TP - 2, 1, float(TP), RockBevel.CORNER_TR), "TR cuts top-right")
	check(_cut(TP - 2, TP - 2, float(TP), RockBevel.CORNER_BR), "BR cuts bottom-right")
	check(_cut(1, TP - 2, float(TP), RockBevel.CORNER_BL), "BL cuts bottom-left")
	check(_cut(1, 1, float(TP), RockBevel.CORNER_TL), "TL cuts top-left")
	check(not _cut(1, 1, float(TP), RockBevel.CORNER_BR), "BR leaves the opposite corner")


func test_active_selection() -> void:
	# A tile with TOP and RIGHT as rock and the TR diagonal as floor is a concave TR
	# corner; its bottom and left are floor, so BL is a convex corner.
	var sides := RockBevel.S_TOP | RockBevel.S_RIGHT
	var corners := 0

	# convex on, concave off (the shipped default): only the convex BL corner bevels.
	var picked := _corner_ids(RockBevel.active(sides, corners, TP, 1.0, 0.0))
	check(picked == [RockBevel.CORNER_BL], "concave off: only the convex BL corner is beveled")

	# concave on: the inner TR corner joins.
	picked = _corner_ids(RockBevel.active(sides, corners, TP, 1.0, 0.5))
	picked.sort()
	check(picked == [RockBevel.CORNER_TR, RockBevel.CORNER_BL], "concave on: the inner TR corner joins")

	# All-floor neighbourhood (a lone outcrop): four convex corners active — the
	# octagon stress test the spec calls out.
	var lone := _corner_ids(RockBevel.active(0, 0, TP, 1.0, 0.0))
	check(lone.size() == 4, "a lone outcrop bevels all four corners")

	# A fully interior cell (all neighbours rock) has no corner to cut.
	var interior := RockBevel.active(15, 15, TP, 1.0, 0.5)
	check(interior.is_empty(), "an interior cell bevels nothing")


func test_collision_polygon() -> void:
	# The collision/occluder polygon (what the player actually walks against) must match
	# the drawn silhouette, or the slope is a lie you can feel — the whole point of 2c.

	# An untouched tile (all neighbours rock) stays the full square: four corners.
	var square := RockBevel.tile_polygon(15, 15, TP, 1.0, 0.0)
	check(square.size() == 4, "an unbeveled tile keeps a square collision")

	# One convex corner at a full leg gives a triangle — the clean 45° ramp of a
	# staircase step. sides = bottom+left rock (so only TR is a convex, floor/floor
	# corner), diagonal BL rock so nothing turns concave.
	var sides := RockBevel.S_BOTTOM | RockBevel.S_LEFT
	var tri := RockBevel.tile_polygon(sides, RockBevel.C_BL, TP, 1.0, 0.0)
	check(tri.size() == 3, "a single full-leg corner gives a triangular ramp")

	# A lone outcrop keeps straight edges only while the leg is under half a cell — then
	# it is an octagon (the shape that betrays a too-small leg on a small mass). At a
	# half leg the chamfers meet and it is a diamond; at a full leg it collapses to
	# nothing, so no collision remains.
	var octagon := RockBevel.tile_polygon(0, 0, TP, 0.3, 0.0)
	check(octagon.size() == 8, "a lone outcrop at a sub-half leg is an octagon")
	var diamond := RockBevel.tile_polygon(0, 0, TP, 0.5, 0.0)
	check(diamond.size() == 4, "at a half leg the chamfers meet — a diamond")
	var collapsed := RockBevel.tile_polygon(0, 0, TP, 1.0, 0.0)
	check(collapsed.is_empty(), "a corner cut to nothing leaves no collision solid")

	# The polygon is centred on the tile (origin at centre, not a 0..tp box).
	var half := float(TP) * 0.5
	var centred := true
	for p in square:
		if absf(p.x) > half + 0.01 or absf(p.y) > half + 0.01:
			centred = false
	check(centred, "the polygon is tile-centred")


func _corner_ids(bevels: Array) -> Array:
	var out: Array = []
	for b in bevels:
		out.append(b[0])
	return out


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
