class_name RoomGeometry
extends RefCounted
## Pure positional maths for a room (M6 Step 2a, extracted from room.gd). No nodes, no
## signals, no engine state — just tile→world arithmetic, so it is unit-testable under
## --script and is the single source of truth for the numbers a room places content by.
## `RockTileSet`/`Door`/`SealedDoor` reference EnvPalette and cannot compile under --script;
## this deliberately does not touch them, so it stays testable (the pure-seam discipline,
## CLAUDE.md §4).
##
## Constructed with the finalised tile size and room extent; `room.gd` builds one after the
## TileSet reports its tile size back (§5.2).

## Tiles inside from a gated link its door leaf sits (§6.4, M5 Step 5a). 1.5 centres the leaf
## in its two-tile reserved footprint; a float so it lands between the footprint's two cells.
const DOOR_INSET := 1.5
## A plain transition entry lands 1 tile inside the destination's mirrored edge (Undertale).
const ENTRY_INSET := 1
## A DOORED link lands the player DOOR_ENTRY_INSET in — clear of the leaf's slab, room-side of
## the open door they came through (5a). Sized to the slab.
const DOOR_ENTRY_INSET := 3.5
## The edge-band exit trigger's thickness across the boundary (Undertale transitions).
const EDGE_TRIGGER_THICKNESS := 24.0

var _px: int
var _size: Vector2i


func _init(tile_px: int, size: Vector2i) -> void:
	_px = tile_px
	_size = size


## The world-space centre of a tile.
func cell_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * _px + _px * 0.5, tile.y * _px + _px * 0.5)


## The unit step from a perimeter tile toward the room interior. Zero for a non-perimeter cell.
func inward(at: Vector2i) -> Vector2i:
	if at.x <= 0:
		return Vector2i(1, 0)
	if at.x >= _size.x - 1:
		return Vector2i(-1, 0)
	if at.y <= 0:
		return Vector2i(0, 1)
	if at.y >= _size.y - 1:
		return Vector2i(0, -1)
	return Vector2i(0, 0)


## Half-tile shift along the opening edge toward the 2-tile gap's true centre. The stored `at`
## is the gap's min-corner cell, so without this the trigger and door sit half a tile off to one
## side. The along-edge axis is whichever one `inward_dir` is not on.
func opening_offset(inward_dir: Vector2i) -> Vector2:
	var along := Vector2(absi(inward_dir.y), absi(inward_dir.x))
	return along * (float(_px) * 0.5)


## A point `inset_tiles` in from a perimeter opening cell, centred across the 2-tile gap. The one
## place doors, sealed doors and doored-link entry landings all resolve to (they shared this exact
## expression before the extraction).
func inset_point(at: Vector2i, inward_dir: Vector2i, inset_tiles: float) -> Vector2:
	return cell_center(at) + Vector2(inward_dir) * (inset_tiles * float(_px)) + opening_offset(inward_dir)


## The edge band's centre: the opening centre pushed out to the room boundary (half a tile
## beyond the perimeter tile's centre, along the outward direction).
func edge_band_position(at: Vector2i, inward_dir: Vector2i) -> Vector2:
	var opening_centre := cell_center(at) + opening_offset(inward_dir)
	return opening_centre - Vector2(inward_dir) * (float(_px) * 0.5)


## The edge band's extent: thin across the boundary, two tiles along the opening.
func edge_band_size(inward_dir: Vector2i) -> Vector2:
	if inward_dir.x != 0:
		return Vector2(EDGE_TRIGGER_THICKNESS, _px * 2.0)
	return Vector2(_px * 2.0, EDGE_TRIGGER_THICKNESS)


## Read a `[x, y]` data array into a Vector2i, tolerating a malformed value as the origin.
static func to_v2i(arr: Variant) -> Vector2i:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 2:
		return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO
