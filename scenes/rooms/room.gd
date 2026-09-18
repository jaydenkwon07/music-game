class_name Room
extends Node2D
## A room built from data (§6.3, Fork B / D-M3-1). Reads its geometry from
## RoomGraph (data/rooms/<room_id>.json), paints a gray-box TileMapLayer with
## collision from the shared TileSet — never per-wall StaticBody2Ds (§2) — and
## instances the room's contents: transition links, note pickups, clue chimes,
## and the doors that gate some links.
##
## Deliberately gray boxes: M3 is layout, not art (§1). Geometry lives in data so
## the whole slice is buildable and reviewable without in-editor painting; real
## tilesets and hand-painting come at M5.
##
## `transition_requested` is forwarded up from the room's RoomLinks so World can
## drive the room swap without being globally addressable (§6.2, §6.4).

signal transition_requested(to_room: String, to_entry: String)

## Which room this is. A thin per-room .tscn sets this; RoomGraph keys everything
## off it.
@export var room_id: String = ""

## Tiles inside from a gated link its door sits, so the instrument state is never
## entered flush against a room edge where a camera push-in has nowhere to go
## (§6.4, design doc §3.7). 4 tiles at 640×360 is the M4 double of M3's 2 (§4.2):
## the room doubled in world units, so the proportional inset doubles with it.
const DOOR_INSET := 4

## Undertale-style transitions (owner call, Session 3): the player walks to the
## very edge of the room and appears at the OPPOSITE edge of the next room. The
## exit trigger is a thin band right at the boundary (transition on reaching the
## end, not a tile early), and a transition entry lands ENTRY_INSET tiles inside
## the destination's matching edge — the mirror of the edge just left.
const ENTRY_INSET := 1
const EDGE_TRIGGER_THICKNESS := 16.0

# Tile size for the placeholder TileSet. 20px makes a 32×18 room exactly 640×360,
# so a one-screen room is a true fixed screen with no scroll (§5.2, §6.7, D-M3-5;
# M4 §4 resolution migration). The Room reads the size back from the built TileSet
# after this seed.
var _tile_px: int = 20
var _size: Vector2i = Vector2i.ZERO
var _entries: Dictionary = {}   # entry_id -> world-space Vector2 (tile centre)


func _ready() -> void:
	var geo := RoomGraph.geometry(room_id)
	if geo.is_empty():
		push_error("Room '%s': no geometry." % room_id)
		return
	_size = _to_v2i(geo.get("size_tiles", [0, 0]))
	_build_tiles(geo.get("grid", []))
	_record_entries(geo.get("entries", {}), geo.get("links", []))
	_build_links(geo.get("links", []))
	_build_pickups(geo.get("pickups", []))
	_build_chimes(geo.get("chimes", []))


## World-space extent, for the camera clamp (§6.2).
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_size) * float(_tile_px))


## World position of a named entry, or the room centre if the id is unknown.
func entry_position(entry_id: String) -> Vector2:
	return _entries.get(entry_id, bounds().get_center())


# --- Building ---

func _build_tiles(grid: Array) -> void:
	var tile_set := RockTileSet.build(_tile_px)
	_tile_px = tile_set.tile_size.x  # single source of truth for the size (§5.2)
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = tile_set
	add_child(layer)
	for y in grid.size():
		var row: String = str(grid[y])
		for x in row.length():
			var atlas: Vector2i
			if row[x] == "#":
				atlas = RockTileSet.wall_atlas(_wall_mask(grid, x, y))
			else:
				atlas = RockTileSet.floor_atlas(_floor_variant(x, y))
			layer.set_cell(Vector2i(x, y), RockTileSet.SOURCE_ID, atlas)


## Which of a wall's four sides face floor — the seam-crack goes on those (§8a).
## Out of bounds counts as not-floor, so the room's outermost edge has no seam.
func _wall_mask(grid: Array, x: int, y: int) -> int:
	var mask := 0
	if _is_floor(grid, x, y - 1):
		mask |= RockTileSet.N
	if _is_floor(grid, x + 1, y):
		mask |= RockTileSet.E
	if _is_floor(grid, x, y + 1):
		mask |= RockTileSet.S
	if _is_floor(grid, x - 1, y):
		mask |= RockTileSet.W
	return mask


func _is_floor(grid: Array, x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return false
	var row: String = str(grid[y])
	if x < 0 or x >= row.length():
		return false
	return row[x] == "."


## A stable per-cell floor variant so the same room always paints the same, but
## neighbouring cells differ: mostly one of the three base variants, occasionally
## the rare detail tile. A cheap spatial hash, not RNG — determinism matters (§5).
func _floor_variant(x: int, y: int) -> int:
	var h := absi((x * 73856093) ^ (y * 19349663))
	if h % 17 == 0:
		return RockTileSet.FLOOR_BASE_VARIANTS + (h % RockTileSet.FLOOR_DETAIL_VARIANTS)
	return h % RockTileSet.FLOOR_BASE_VARIANTS


## A transition entry (`from_*`) lands just inside the destination's matching edge,
## centred on the opening — the mirror of the edge the player just left, so exiting
## one room's right lands at the next room's left at the same height (Undertale).
## Other entries (`spawn`) keep their authored position.
func _record_entries(entries: Dictionary, links: Array) -> void:
	for entry_id in entries:
		var cell := _to_v2i(entries[entry_id])
		if str(entry_id).begins_with("from_"):
			var link := _nearest_link(links, cell)
			if not link.is_empty():
				var at := _to_v2i(link.get("at", [0, 0]))
				var inward := _inward(at)
				_entries[str(entry_id)] = _cell_center(at + inward * ENTRY_INSET) + _opening_offset(inward)
				continue
		_entries[str(entry_id)] = _cell_center(cell)


## The link whose opening a transition entry belongs to — the nearest one. The
## authored entry cell only has to point at the right opening; the exact landing
## spot is derived from that link's geometry.
func _nearest_link(links: Array, cell: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for link in links:
		var distance := Vector2(cell - _to_v2i(link.get("at", [0, 0]))).length()
		if distance < best_distance:
			best_distance = distance
			best = link
	return best


func _build_links(links: Array) -> void:
	for link_def in links:
		var at := _to_v2i(link_def.get("at", [0, 0]))
		var inward := _inward(at)
		var link := RoomLink.new()
		link.to_room = str(link_def.get("to_room", ""))
		link.to_entry = str(link_def.get("to_entry", ""))
		# A thin band straddling the room boundary, spanning the opening: the player
		# transitions on reaching the very edge, not a tile early (Undertale). It
		# reaches a little past the boundary so a fast walker can't tunnel out.
		link.size = _edge_band_size(inward)
		link.position = _edge_band_position(at, inward)
		link.transition_requested.connect(_on_link_transition)
		add_child(link)

		var door_id := str(link_def.get("door", ""))
		if not door_id.is_empty():
			_build_door(door_id, at, inward)


## The edge band's centre: the opening centre pushed out to the room boundary
## (half a tile beyond the perimeter tile's centre, along the outward direction).
func _edge_band_position(at: Vector2i, inward: Vector2i) -> Vector2:
	var opening_centre := _cell_center(at) + _opening_offset(inward)
	return opening_centre - Vector2(inward) * (float(_tile_px) * 0.5)


## The edge band's extent: thin across the boundary, two tiles along the opening.
func _edge_band_size(inward: Vector2i) -> Vector2:
	if inward.x != 0:
		return Vector2(EDGE_TRIGGER_THICKNESS, _tile_px * 2.0)
	return Vector2(_tile_px * 2.0, EDGE_TRIGGER_THICKNESS)


## A gated link's door sits DOOR_INSET tiles inside from the link, blocking the
## corridor to it (§6.4). "Inside" is whichever perimeter edge the link is on.
func _build_door(door_id: String, link_at: Vector2i, inward: Vector2i) -> void:
	var door := Door.new()
	door.melody_id = door_id
	door.position = _cell_center(link_at + inward * DOOR_INSET) + _opening_offset(inward)
	add_child(door)


func _build_pickups(pickups: Array) -> void:
	for pickup_def in pickups:
		var pickup := NotePickup.new()
		pickup.note_id = str(pickup_def.get("note_id", ""))
		pickup.position = _cell_center(_to_v2i(pickup_def.get("at", [0, 0])))
		add_child(pickup)


func _build_chimes(chimes: Array) -> void:
	for chime_def in chimes:
		var chime := MelodyChime.new()
		chime.melody_id = str(chime_def.get("melody_id", ""))
		chime.position = _cell_center(_to_v2i(chime_def.get("at", [0, 0])))
		add_child(chime)


func _on_link_transition(to_room: String, to_entry: String) -> void:
	transition_requested.emit(to_room, to_entry)


# --- Geometry helpers ---

## Half-tile shift along the opening edge toward the gap's true centre. A migrated
## opening is 2 tiles wide (§4.2) and the stored `at` is its min-corner cell, so
## the link trigger and the door would otherwise sit half a tile off to one side
## of the gap. The along-edge axis is whichever one `inward` is not on.
func _opening_offset(inward: Vector2i) -> Vector2:
	var along := Vector2(absi(inward.y), absi(inward.x))
	return along * (float(_tile_px) * 0.5)


## The unit step from a perimeter tile toward the room interior.
func _inward(at: Vector2i) -> Vector2i:
	if at.x <= 0:
		return Vector2i(1, 0)
	if at.x >= _size.x - 1:
		return Vector2i(-1, 0)
	if at.y <= 0:
		return Vector2i(0, 1)
	if at.y >= _size.y - 1:
		return Vector2i(0, -1)
	return Vector2i(0, 0)


func _cell_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * _tile_px + _tile_px * 0.5, tile.y * _tile_px + _tile_px * 0.5)


func _to_v2i(arr: Variant) -> Vector2i:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 2:
		return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO
