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
## (§6.4, design doc §3.7).
const DOOR_INSET := 2

# Tile size for the placeholder TileSet. 20px makes a 16×9 room exactly 320×180,
# so a one-screen room is a true fixed screen with no scroll (§5.2, §6.7, D-M3-5).
# The Room reads the size back from the built TileSet after this seed.
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
	_record_entries(geo.get("entries", {}))
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
	var tile_set := GrayTileSet.build(_tile_px)
	_tile_px = tile_set.tile_size.x  # single source of truth for the size (§5.2)
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = tile_set
	add_child(layer)
	for y in grid.size():
		var row: String = str(grid[y])
		for x in row.length():
			var atlas := GrayTileSet.WALL_ATLAS if row[x] == "#" else GrayTileSet.FLOOR_ATLAS
			layer.set_cell(Vector2i(x, y), GrayTileSet.SOURCE_ID, atlas)


func _record_entries(entries: Dictionary) -> void:
	for entry_id in entries:
		_entries[str(entry_id)] = _cell_center(_to_v2i(entries[entry_id]))


func _build_links(links: Array) -> void:
	for link_def in links:
		var at := _to_v2i(link_def.get("at", [0, 0]))
		var link := RoomLink.new()
		link.to_room = str(link_def.get("to_room", ""))
		link.to_entry = str(link_def.get("to_entry", ""))
		link.size = Vector2(_tile_px, _tile_px)  # fill the opening cell
		link.position = _cell_center(at)
		link.transition_requested.connect(_on_link_transition)
		add_child(link)

		var door_id := str(link_def.get("door", ""))
		if not door_id.is_empty():
			_build_door(door_id, at)


## A gated link's door sits DOOR_INSET tiles inside from the link, blocking the
## corridor to it (§6.4). "Inside" is whichever perimeter edge the link is on.
func _build_door(door_id: String, link_at: Vector2i) -> void:
	var door := Door.new()
	door.melody_id = door_id
	door.position = _cell_center(link_at + _inward(link_at) * DOOR_INSET)
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
