extends Node
## The room graph (§5.1, §7.5), loaded from data/rooms.json at boot.
##
## The graph — which rooms exist, how they connect, which exits are door-gated,
## which notes live where — is data so the solvability validator can run as
## standalone Python in CI without booting Godot (§7.4). This autoload is the
## in-engine reader of the same file; lookups only, no gameplay decisions.
##
## It also loads the per-room GEOMETRY files (data/rooms/<id>.json) — kept as
## separate files from the graph so validation data and rendering data do not
## entangle (D-M3-6) — and cross-checks the two at boot (§5.3). A mismatch is a
## loud error, not a silent misroute.

const ROOMS_PATH := "res://data/rooms.json"
const GEOMETRY_DIR := "res://data/rooms"

var _start: Dictionary = {}     # {room, entry}
var _rooms: Dictionary = {}     # room_id -> {display_name, notes, entries, exits}
var _geometry: Dictionary = {}  # room_id -> geometry dict (grid, entries, links, pickups, chimes)


func _ready() -> void:
	reload()


func reload() -> void:
	_start.clear()
	_rooms.clear()
	_geometry.clear()
	_load_graph()
	_load_geometry()
	_check_consistency()


# --- Lookups (the contract with World / Room) ---

## The room record for an id, or {} if unknown.
func room(room_id: String) -> Dictionary:
	return _rooms.get(room_id, {})


## A room's exits: [{to, to_entry, door?, requires?}] (door and requires may both be absent
## for a free gap; an exit carries at most one of the two).
func exits(room_id: String) -> Array:
	return room(room_id).get("exits", [])


## Where the slice begins: {room, entry}.
func start() -> Dictionary:
	return _start


func has_entry(room_id: String, entry: String) -> bool:
	return entry in room(room_id).get("entries", [])


## The per-room geometry (grid + spatial placements) the Room paints from.
func geometry(room_id: String) -> Dictionary:
	return _geometry.get(room_id, {})


# --- Loading ---

func _load_graph() -> void:
	var parsed := _read_json(ROOMS_PATH)
	if parsed.is_empty():
		return
	_start = parsed.get("start", {})
	var rooms: Dictionary = parsed.get("rooms", {})
	for room_id: String in rooms:
		_rooms[room_id] = rooms[room_id]


func _load_geometry() -> void:
	for room_id: String in _rooms:
		var path := GEOMETRY_DIR.path_join("%s.json" % room_id)
		var geo := _read_json(path)
		if geo.is_empty():
			push_warning("RoomGraph: geometry missing for '%s' (%s)." % [room_id, path])
			continue
		_geometry[room_id] = geo


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("RoomGraph: could not open %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RoomGraph: %s is not a JSON object." % path)
		return {}
	return parsed


# --- Consistency (§5.3): fail loudly rather than misroute silently ---

func _check_consistency() -> void:
	if _start.is_empty() or not _rooms.has(str(_start.get("room", ""))):
		push_error("RoomGraph: start room '%s' is not defined." % str(_start.get("room", "")))
	for room_id: String in _rooms:
		_check_room(room_id)


func _check_room(room_id: String) -> void:
	var rec: Dictionary = _rooms[room_id]

	# Every note the room contains must be a known note id (§5.3).
	for note_id in rec.get("notes", []):
		if NoteRegistry.by_id(str(note_id)).is_empty():
			push_error("RoomGraph[%s]: unknown note id '%s'." % [room_id, note_id])

	# Every exit must target an existing room + entry, and any gate must be a
	# known melody id (§5.3).
	for exit in rec.get("exits", []):
		var to: String = str(exit.get("to", ""))
		var to_entry: String = str(exit.get("to_entry", ""))
		if not _rooms.has(to):
			push_error("RoomGraph[%s]: exit to unknown room '%s'." % [room_id, to])
		elif not has_entry(to, to_entry):
			push_error("RoomGraph[%s]: exit to '%s' names missing entry '%s'." % [room_id, to, to_entry])
		var door: String = str(exit.get("door", ""))
		if not door.is_empty() and MelodyLibrary.get_melody(door).is_empty():
			push_error("RoomGraph[%s]: exit gated by unknown melody '%s'." % [room_id, door])

		var req: Dictionary = exit.get("requires", {})
		if not req.is_empty():
			if not door.is_empty():
				push_error("RoomGraph[%s]: exit %s has both a door and a requires." % [room_id, exit])
			var req_note := str(req.get("note", ""))
			if NoteRegistry.by_id(req_note).is_empty():
				push_error("RoomGraph[%s]: ability gate names unknown note '%s'." % [room_id, req_note])

	# The geometry must mirror the graph: every graph exit needs a matching link,
	# and every geometry entry/link must name a defined entry (§5.3).
	var geo: Dictionary = _geometry.get(room_id, {})
	if geo.is_empty():
		return
	var links: Array = geo.get("links", [])
	for exit in rec.get("exits", []):
		if not _link_matches(links, exit):
			push_error("RoomGraph[%s]: graph exit %s has no matching geometry link." % [room_id, exit])
	for entry_name in geo.get("entries", {}):
		if not has_entry(room_id, str(entry_name)):
			push_error("RoomGraph[%s]: geometry entry '%s' is not in the graph." % [room_id, entry_name])


func _link_matches(links: Array, exit: Dictionary) -> bool:
	for link in links:
		if (
			str(link.get("to_room", "")) == str(exit.get("to", ""))
			and str(link.get("to_entry", "")) == str(exit.get("to_entry", ""))
			and str(link.get("door", "")) == str(exit.get("door", ""))
			and str((link.get("requires", {}) as Dictionary).get("note", "")) == str((exit.get("requires", {}) as Dictionary).get("note", ""))
		):
			return true
	return false
