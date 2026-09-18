class_name NotePickup
extends Interactable
## A collectible note lying in the world (§7 Step 1). Knows only its note ID; its
## pitch, category and colour are all resolved through NoteRegistry, so no pitch
## and no colour is authored here (§3).
##
## Collected by pressing `interact` (space) while standing on it — the one world
## verb (owner decision, Session 8), which also covers doors, NPCs and hints
## later. This replaced the original walk-in collection.
##
## Instantiated in code like the resonators (main.gd); scaffolding, not a placed
## .tscn, until rooms become real scenes at M3.

@export var note_id: String = ""
## Drawn radius. The interact range is Interactable.radius, set a little larger so
## the note is collectable from contact, not pixel-perfect overlap.
@export var draw_radius: float = 12.0
## The pickup IS a light (§5.2): a bright pool in its own note colour, so it
## announces itself before the player can see the floor around it (§5.4).
@export var light_radius: float = 60.0
@export var light_energy: float = 0.8

var _collected: bool = false


func _ready() -> void:
	super._ready()
	# Rooms are re-instanced on every transition (§6.3a); a note already taken must
	# not reappear on the return trip. WorldState remembers this, keyed by note id.
	if WorldState.is_pickup_taken(note_id):
		queue_free()
		return
	add_child(Lighting.make_light(light_radius, light_energy, _note_color(), false))


func _note_color() -> Color:
	var note := NoteRegistry.by_id(note_id)
	if note.is_empty():
		return NoteColors.NEUTRAL
	return NoteColors.color(note["category"], note["index"], NoteInventory.OVERWORLD_OCTAVE)


## Only offer to be collected while it still holds an uncollected note.
func can_interact() -> bool:
	return not _collected


func interact(_player: Node2D) -> void:
	# collect() rejects an unknown or already-owned id; only vanish on success so
	# a duplicate pickup stays put rather than silently disappearing.
	if NoteInventory.collect(note_id):
		_collected = true
		WorldState.mark_pickup_taken(note_id)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, draw_radius, _note_color())
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 24, EnvPalette.with_alpha("ink", 0.5), 1.0)
