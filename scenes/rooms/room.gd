class_name Room
extends Node2D
## A room built from data (§6.3, Fork B / D-M3-1). Reads its geometry from RoomGraph
## (data/rooms/<room_id>.json), paints a TileMapLayer with collision from the shared TileSet —
## never per-wall StaticBody2Ds (§2) — and instances the room's contents: transition links,
## note pickups, clue chimes, decorative props/sealed doors, and the doors that gate some
## links.
##
## [M6 Step 2a] The positional maths lives in the pure, unit-tested `RoomGeometry`, and content
## instancing in `RoomContent`, so this file stays orchestration + tile painting + link wiring
## and stops growing every time a content type is added. Numbers are unchanged from M5 — the
## Cistern's LOCKED geometry is preserved.
##
## `transition_requested` is forwarded up from the room's RoomLinks so World can drive the room
## swap without being globally addressable (§6.2, §6.4).

signal transition_requested(to_room: String, to_entry: String)

## Which room this is. A thin per-room .tscn sets this; RoomGraph keys everything off it.
@export var room_id: String = ""

## The cave tile look (M5 Step 2b). Left null uses RockStyle's defaults; assign a .tres to
## retune floor/rock value gap, seam and grit without touching code.
@export var rock_style: RockStyle

# Tile size for the TileSet. 30px makes a 32×18 room exactly 960×540, so a one-screen room is a
# true fixed screen with no scroll (§5.2, §6.7, D-M3-5). The Room reads the size back from the
# built TileSet after this seed.
var _tile_px: int = 30
var _size: Vector2i = Vector2i.ZERO
var _entries: Dictionary = {}   # entry_id -> world-space Vector2 (tile centre)
var _geom: RoomGeometry


func _ready() -> void:
	var geo := RoomGraph.geometry(room_id)
	if geo.is_empty():
		push_error("Room '%s': no geometry." % room_id)
		return
	_size = RoomGeometry.to_v2i(geo.get("size_tiles", [0, 0]))
	_build_tiles(geo.get("grid", []))
	_geom = RoomGeometry.new(_tile_px, _size)  # after the TileSet reports the final tile size
	RoomContent.build_props(self, _geom, geo.get("props", []))
	_record_entries(geo.get("entries", {}), geo.get("links", []))
	_build_links(geo.get("links", []))
	RoomContent.build_pickups(self, _geom, geo.get("pickups", []))
	RoomContent.build_chimes(self, _geom, geo.get("chimes", []))
	RoomContent.build_sealed_doors(self, _geom, geo.get("sealed_doors", []))


## World-space extent, for the camera clamp (§6.2).
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_size) * float(_tile_px))


## World position of a named entry, or the room centre if the id is unknown.
func entry_position(entry_id: String) -> Vector2:
	return _entries.get(entry_id, bounds().get_center())


# --- Tiles ---

## Floor cells are painted directly with a spatial-hash variant; rock cells are handed to Godot's
## terrain system, which picks the blob tile per cell from its neighbourhood (M5 Step 1). A
## one-cell rock ring is added outside the grid so the room's outer perimeter reads as solid rock
## rather than bevelling into the void — those ring cells sit beyond the camera clamp and behind
## the perimeter wall, so the player never sees or reaches them.
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


## A stable per-cell floor variant so the same room always paints the same, but neighbouring cells
## differ: mostly one of the three base variants, occasionally the rare detail tile. A cheap
## spatial hash, not RNG — determinism matters (§5). Stays here (not in RoomGeometry) because it
## references RockTileSet's variant counts, which don't compile under --script.
func _floor_variant(x: int, y: int) -> int:
	var h := absi((x * 73856093) ^ (y * 19349663))
	if h % 17 == 0:
		return RockTileSet.FLOOR_BASE_VARIANTS + (h % RockTileSet.FLOOR_DETAIL_VARIANTS)
	return h % RockTileSet.FLOOR_BASE_VARIANTS


# --- Entries and links ---

## A transition entry (`from_*`) lands just inside the destination's matching edge, centred on the
## opening — the mirror of the edge the player just left, so exiting one room's right lands at the
## next room's left at the same height (Undertale). Other entries (`spawn`) keep their authored
## position. A doored link lands the player room-side of the leaf, not in it (5a).
func _record_entries(entries: Dictionary, links: Array) -> void:
	for entry_id in entries:
		var cell := RoomGeometry.to_v2i(entries[entry_id])
		if str(entry_id).begins_with("from_"):
			var link := _nearest_link(links, cell)
			if not link.is_empty():
				var at := RoomGeometry.to_v2i(link.get("at", [0, 0]))
				var inward := _geom.inward(at)
				var inset := RoomGeometry.DOOR_ENTRY_INSET if not str(link.get("door", "")).is_empty() else float(RoomGeometry.ENTRY_INSET)
				_entries[str(entry_id)] = _geom.inset_point(at, inward, inset)
				continue
		_entries[str(entry_id)] = _geom.cell_center(cell)


## The link whose opening a transition entry belongs to — the nearest one. The authored entry cell
## only has to point at the right opening; the exact landing spot is derived from that link's
## geometry.
func _nearest_link(links: Array, cell: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for link in links:
		var distance := Vector2(cell - RoomGeometry.to_v2i(link.get("at", [0, 0]))).length()
		if distance < best_distance:
			best_distance = distance
			best = link
	return best


func _build_links(links: Array) -> void:
	for link_def in links:
		var at := RoomGeometry.to_v2i(link_def.get("at", [0, 0]))
		var inward := _geom.inward(at)
		var link := RoomLink.new()
		link.to_room = str(link_def.get("to_room", ""))
		link.to_entry = str(link_def.get("to_entry", ""))
		# A thin band straddling the room boundary, spanning the opening: the player transitions on
		# reaching the very edge, not a tile early (Undertale). It reaches a little past the
		# boundary so a fast walker can't tunnel out.
		link.size = _geom.edge_band_size(inward)
		link.position = _geom.edge_band_position(at, inward)
		link.transition_requested.connect(_on_link_transition)
		add_child(link)

		var door_id := str(link_def.get("door", ""))
		if not door_id.is_empty():
			RoomContent.build_door(self, _geom, door_id, at, inward)


func _on_link_transition(to_room: String, to_entry: String) -> void:
	transition_requested.emit(to_room, to_entry)
