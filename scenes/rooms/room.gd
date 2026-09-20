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

## The cave tile look (M5 Step 2b). Left null uses RockStyle's defaults; assign a
## .tres to retune floor/rock value gap, seam and grit without touching code.
@export var rock_style: RockStyle

## Tiles inside from a gated link its door sits (§6.4, design doc §3.7). M5 Step 5a:
## dropped 4 → 1.5 so the leaf lands centred in its RESERVED FOOTPRINT (the mask's
## two-tile door slot, e.g. N cols 23–24 rows 1–2), not a tile past it in the
## approach-clearance band. 1.5 is the distance from the link tile's centre to the
## footprint centre and is the same on both edges, so one inset serves both. Float,
## so the door centres between the footprint's two tiles rather than on a grid line.
const DOOR_INSET := 1.5

## Undertale-style transitions (owner call, Session 3): the player walks to the
## very edge of the room and appears at the OPPOSITE edge of the next room. The
## exit trigger is a thin band right at the boundary (transition on reaching the
## end, not a tile early), and a transition entry lands ENTRY_INSET tiles inside
## the destination's matching edge — the mirror of the edge just left.
const ENTRY_INSET := 1
## Where a DOORED link's entry lands (5a). The door leaf now sits at DOOR_INSET in its
## footprint, so the plain 1-tile landing would drop the player inside the leaf's slab
## (and, at 5b, on the door art). This clears the 72×90 slab and puts them room-side of
## the open door they just came through. Sized to the slab; revisit if slab_size changes.
const DOOR_ENTRY_INSET := 3.5
const EDGE_TRIGGER_THICKNESS := 24.0

# Tile size for the placeholder TileSet. 30px makes a 32×18 room exactly 960×540,
# so a one-screen room is a true fixed screen with no scroll (§5.2, §6.7, D-M3-5;
# M4 §4 migration, then bumped 20→30px at the 640→960 resolution step — the grid is
# unchanged, only the tile size). The Room reads the size back from the built
# TileSet after this seed.
var _tile_px: int = 30
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

## Floor cells are painted directly with a spatial-hash variant; rock cells are
## handed to Godot's terrain system, which picks the blob tile per cell from its
## neighbourhood (M5 Step 1). A one-cell rock ring is added outside the grid so the
## room's outer perimeter reads as solid rock rather than bevelling into the void —
## those ring cells sit beyond the camera clamp and behind the perimeter wall, so
## the player never sees or reaches them.
func _build_tiles(grid: Array) -> void:
	var tile_set := RockTileSet.build(_tile_px, rock_style)
	_tile_px = tile_set.tile_size.x  # single source of truth for the size (§5.2)
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = tile_set
	add_child(layer)

	var rock_cells: Array[Vector2i] = []
	for y in grid.size():
		var row: String = str(grid[y])
		for x in row.length():
			# '#' is solid rock; 'o' is an interior outcrop — also rock for terrain and
			# collision, kept a distinct symbol only so the mask can count it apart from
			# "unreached" perimeter rock (M5 Step 4). Everything else is floor.
			if row[x] == "#" or row[x] == "o":
				rock_cells.append(Vector2i(x, y))
			else:
				layer.set_cell(Vector2i(x, y), RockTileSet.SOURCE_ID, RockTileSet.floor_atlas(_floor_variant(x, y)))

	for x in range(-1, _size.x + 1):
		rock_cells.append(Vector2i(x, -1))
		rock_cells.append(Vector2i(x, _size.y))
	for y in range(_size.y):
		rock_cells.append(Vector2i(-1, y))
		rock_cells.append(Vector2i(_size.x, y))

	layer.set_cells_terrain_connect(rock_cells, RockTileSet.TERRAIN_SET, RockTileSet.ROCK_TERRAIN)


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
				# A doored link lands the player room-side of the leaf, not in it (5a).
				var inset := DOOR_ENTRY_INSET if not str(link.get("door", "")).is_empty() else float(ENTRY_INSET)
				_entries[str(entry_id)] = (
					_cell_center(at)
					+ Vector2(inward) * (inset * float(_tile_px))
					+ _opening_offset(inward)
				)
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
## corridor to it (§6.4). "Inside" is whichever perimeter edge the link is on. The
## inset is fractional (5a), so the offset is computed in world units off the link
## cell's centre rather than by integer tile arithmetic.
func _build_door(door_id: String, link_at: Vector2i, inward: Vector2i) -> void:
	var door := Door.new()
	door.melody_id = door_id
	door.position = (
		_cell_center(link_at)
		+ Vector2(inward) * (DOOR_INSET * float(_tile_px))
		+ _opening_offset(inward)
	)
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
