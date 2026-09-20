extends SceneTree
## Unit tests for the door orientation maths (M5 Step 5b). No nodes, no scenes.
##
## Run:  godot --headless --script tests/test_door_layout.gd
##
## Targets DoorLayout, the pure seam — NOT DoorArt/DoorGems, which reference EnvPalette and
## can't compile under --script. These pin the facing convention the 5b redesign turns on:
## the gem bar sits on the ROOM side (N→below, E→left), the pipes run across the opening,
## and a horizontal door swaps the slab's across/depth extents.

const SLAB := Vector2(72.0, 90.0)  # authored across×depth for a vertical (N/S) door

var _passed := 0
var _failed := 0

const N := Vector2i(0, 1)    # north door faces SOUTH (into the room, downward)
const E := Vector2i(-1, 0)   # east door faces WEST (into the room, leftward)


func _initialize() -> void:
	test_across_axis()
	test_extents_swap_for_horizontal()
	test_gem_bar_on_room_side()
	test_gems_centred_and_ordered()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func test_across_axis() -> void:
	check(DoorLayout.across(N) == Vector2(1, 0), "N door: gems/pipes run horizontally")
	check(DoorLayout.across(E) == Vector2(0, 1), "E door: gems/pipes run vertically")


func test_extents_swap_for_horizontal() -> void:
	check(is_equal_approx(DoorLayout.depth_extent(N, SLAB), 90.0), "N door depth is the tall axis")
	check(is_equal_approx(DoorLayout.across_extent(N, SLAB), 72.0), "N door span is the wide axis")
	check(is_equal_approx(DoorLayout.depth_extent(E, SLAB), 72.0), "E door depth swaps to the wide axis")
	check(is_equal_approx(DoorLayout.across_extent(E, SLAB), 90.0), "E door span swaps to the tall axis")


func test_gem_bar_on_room_side() -> void:
	# N faces south → bar below the door (y > 0). E faces west → bar left (x < 0).
	var cn := DoorLayout.gem_row_center(N, SLAB, 15.0)
	check(cn.x == 0.0 and cn.y > 0.0, "N door gem bar sits below (room side), centred across")
	var ce := DoorLayout.gem_row_center(E, SLAB, 15.0)
	check(ce.y == 0.0 and ce.x < 0.0, "E door gem bar sits left (room side), centred across")


func test_gems_centred_and_ordered() -> void:
	# Three gems on a N door: laid along +x, symmetric about the row centre, in order.
	var p0 := DoorLayout.gem_position(0, 3, N, SLAB, 15.0, 22.0)
	var p1 := DoorLayout.gem_position(1, 3, N, SLAB, 15.0, 22.0)
	var p2 := DoorLayout.gem_position(2, 3, N, SLAB, 15.0, 22.0)
	check(p0.x < p1.x and p1.x < p2.x, "gems are ordered along the across axis")
	check(is_equal_approx(p1.x, 0.0), "the middle of three gems is centred")
	check(is_equal_approx(p0.x, -p2.x), "the row is symmetric about the centre")
	check(is_equal_approx(p0.y, p2.y), "all gems share the row's depth offset")


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
