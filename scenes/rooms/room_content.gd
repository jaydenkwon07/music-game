class_name RoomContent
extends RefCounted
## Instances a room's content nodes from data (M6 Step 2a, extracted from room.gd) so new
## content types stop growing room.gd — the same move that produced door_gems/door_art. It
## owns instancing ONLY: every placement number comes from the RoomGeometry it is handed, and
## each node is added as a child of the room. It references Door/Prop/NotePickup/… (which in
## turn reference EnvPalette), so like room.gd it does not compile under --script; the maths it
## leans on is tested through RoomGeometry.


## Decorative detail props (M5 Step 5e): rubble piles. No collision or light — placed on floor
## for look only, so they never affect the frozen geometry, the validator or the seal test. The
## cell seeds the deterministic shape.
static func build_props(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for prop_def in defs:
		var cell := RoomGeometry.to_v2i(prop_def.get("at", [0, 0]))
		var prop := Prop.new()
		prop.seed_xy = cell
		prop.position = geom.cell_center(cell)
		parent.add_child(prop)


static func build_pickups(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for pickup_def in defs:
		var pickup := NotePickup.new()
		pickup.note_id = str(pickup_def.get("note_id", ""))
		pickup.position = geom.cell_center(RoomGeometry.to_v2i(pickup_def.get("at", [0, 0])))
		parent.add_child(pickup)


static func build_chimes(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for chime_def in defs:
		var chime := MelodyChime.new()
		chime.melody_id = str(chime_def.get("melody_id", ""))
		chime.position = geom.cell_center(RoomGeometry.to_v2i(chime_def.get("at", [0, 0])))
		parent.add_child(chime)


## Decorative sealed doors (§7.5, M5 Step 5c): unopenable five-note doors with no link, melody
## or lock. Placed from a perimeter opening exactly like a real door (DOOR_INSET + opening
## centring) and facing inward, so they land in the same reserved footprint and read as the
## same family.
static func build_sealed_doors(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for door_def in defs:
		var at := RoomGeometry.to_v2i(door_def.get("at", [0, 0]))
		var inward := geom.inward(at)
		var sealed := SealedDoor.new()
		sealed.facing = inward
		sealed.socket_count = int(door_def.get("sockets", 5))
		sealed.position = geom.inset_point(at, inward, RoomGeometry.DOOR_INSET)
		parent.add_child(sealed)


## A gated link's door leaf, sitting DOOR_INSET tiles inside from the link and blocking the
## corridor to it (§6.4). `inward` (into the room) drives the gem-bar and carved-art
## orientation (5b). Called by room.gd while it builds the link that owns the door.
static func build_door(parent: Node2D, geom: RoomGeometry, door_id: String, link_at: Vector2i, inward: Vector2i) -> void:
	var door := Door.new()
	door.melody_id = door_id
	door.facing = inward
	door.position = geom.inset_point(link_at, inward, RoomGeometry.DOOR_INSET)
	parent.add_child(door)


## An inter-room ability gate: the leaf of a `requires` link, placed like a door leaf.
static func build_ability_gate(parent: Node2D, geom: RoomGeometry, note_id: String, link_at: Vector2i, inward: Vector2i) -> void:
	var gate := AbilityGate.new()
	gate.required_note = note_id
	gate.facing = inward
	gate.position = geom.inset_point(link_at, inward, RoomGeometry.DOOR_INSET)
	parent.add_child(gate)


## Internal ability gates (e.g. the Span fissure): a blocker inside the room, not on an edge.
static func build_ability_gates(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for d in defs:
		var gate := AbilityGate.new()
		gate.required_note = str(d.get("note", ""))
		gate.facing = RoomGeometry.to_v2i(d.get("facing", [0, 1]))
		gate.position = geom.cell_center(RoomGeometry.to_v2i(d.get("at", [0, 0])))
		parent.add_child(gate)
