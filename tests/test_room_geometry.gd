extends SceneTree
## Unit tests for RoomGeometry, the pure room-placement maths (M6 Step 2a). No nodes, no
## scenes.
##
## Run:  godot --headless --script tests/test_room_geometry.gd
##
## These CHARACTERISE the exact numbers room.gd placed content by before the extraction, at
## the Cistern's parameters (30px tiles, 48×36). If a value here changes, a room's doors,
## triggers or landings moved — and the Cistern's geometry is LOCKED, so that must be
## deliberate.

const PX := 30
const SIZE := Vector2i(48, 36)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_cell_center()
	test_inward()
	test_opening_offset()
	test_inset_point()
	test_edge_band()
	test_to_v2i()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _geom() -> RoomGeometry:
	return RoomGeometry.new(PX, SIZE)


func test_cell_center() -> void:
	var g := _geom()
	check(g.cell_center(Vector2i(0, 0)) == Vector2(15, 15), "origin cell centres at half a tile")
	check(g.cell_center(Vector2i(2, 3)) == Vector2(75, 105), "cell centre is tile*px + px/2")


func test_inward() -> void:
	var g := _geom()
	check(g.inward(Vector2i(0, 5)) == Vector2i(1, 0), "west edge points in +x")
	check(g.inward(Vector2i(47, 5)) == Vector2i(-1, 0), "east edge points in -x")
	check(g.inward(Vector2i(5, 0)) == Vector2i(0, 1), "north edge points in +y")
	check(g.inward(Vector2i(5, 35)) == Vector2i(0, -1), "south edge points in -y")
	check(g.inward(Vector2i(10, 10)) == Vector2i(0, 0), "an interior cell has no inward")


func test_opening_offset() -> void:
	var g := _geom()
	check(g.opening_offset(Vector2i(1, 0)) == Vector2(0, 15), "a vertical edge shifts half a tile in y")
	check(g.opening_offset(Vector2i(0, 1)) == Vector2(15, 0), "a horizontal edge shifts half a tile in x")


func test_inset_point() -> void:
	var g := _geom()
	# West opening at (0,5): cell_center (15,165) + inward*(1.5*30=45) + opening (0,15) = (60,180).
	check(g.inset_point(Vector2i(0, 5), Vector2i(1, 0), RoomGeometry.DOOR_INSET) == Vector2(60, 180),
		"door inset point matches the pre-extraction expression")
	# Same opening, the doored-entry landing further in (3.5 tiles): (15,165)+(105,0)+(0,15)=(120,180).
	check(g.inset_point(Vector2i(0, 5), Vector2i(1, 0), RoomGeometry.DOOR_ENTRY_INSET) == Vector2(120, 180),
		"doored-entry landing clears the slab")


func test_edge_band() -> void:
	var g := _geom()
	check(g.edge_band_size(Vector2i(1, 0)) == Vector2(24, 60), "vertical edge band: thin in x, 2 tiles in y")
	check(g.edge_band_size(Vector2i(0, 1)) == Vector2(60, 24), "horizontal edge band: 2 tiles in x, thin in y")
	# Opening (0,5) on the west edge: (15,165)+(0,15) - inward*(15) = (0,180) at the boundary.
	check(g.edge_band_position(Vector2i(0, 5), Vector2i(1, 0)) == Vector2(0, 180),
		"edge band sits on the boundary, centred on the opening")


func test_to_v2i() -> void:
	check(RoomGeometry.to_v2i([3, 4]) == Vector2i(3, 4), "a [x,y] array reads back as a Vector2i")
	check(RoomGeometry.to_v2i("bad") == Vector2i.ZERO, "a malformed value falls back to the origin")


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
