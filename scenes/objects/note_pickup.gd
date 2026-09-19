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
## Diamond half-extent (point-to-centre). Its SILHOUETTE — a floating diamond, not
## a circle — is what distinguishes a takeable pickup from a struck chime, so the
## two never read as the same object in the dark or colourblind (§6, D-M4-7). The
## interact range is Interactable.radius, set a little larger so the note is
## collectable from contact, not pixel-perfect overlap.
@export var draw_radius: float = 18.0
## The pickup IS a light (§5.2): a bright pool in its own note colour, so it
## announces itself before the player can see the floor around it (§5.4).
@export var light_radius: float = 90.0
@export var light_energy: float = 0.8
## Floating motion, tuned by feel (§10). The spin and bob live entirely in _draw —
## the node transform, and so the collision shape and interact_point, never move —
## so "clearly takeable" costs nothing in interaction geometry.
@export var spin_speed: float = 1.2   ## radians/sec
@export var bob_speed: float = 2.4    ## radians/sec
@export var bob_amplitude: float = 3.0  ## pixels

var _collected: bool = false
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	# Rooms are re-instanced on every transition (§6.3a); a note already taken must
	# not reappear on the return trip. WorldState remembers this, keyed by note id.
	if WorldState.is_pickup_taken(note_id):
		queue_free()
		return
	add_child(Lighting.make_light(light_radius, light_energy, _note_color(), false))


## Advance the float; the shape is redrawn each frame, the node never moves.
func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _note_color() -> Color:
	var note := NoteRegistry.by_id(note_id)
	if note.is_empty():
		return NoteColors.NEUTRAL
	return NoteColors.color(note["category"], note["index"], NoteInventory.OVERWORLD_OCTAVE)


## Only offer to be collected while it still holds an uncollected note.
func can_interact() -> bool:
	return not _collected


func interact(player: Node2D) -> void:
	# collect() rejects an unknown or already-owned id; only vanish on success so
	# a duplicate pickup stays put rather than silently disappearing.
	if NoteInventory.collect(note_id):
		_collected = true
		WorldState.mark_pickup_taken(note_id)
		_spawn_collect_flash(player)
		queue_free()


## The note's light lifts off and folds into the player (§9). Parented to the World
## host, not to us — we're about to free — mirroring how NoteVisuals spawns rings.
func _spawn_collect_flash(player: Node2D) -> void:
	var host := get_tree().get_first_node_in_group("world")
	if host == null or player == null:
		return
	host.add_child(CollectFlash.spawn(_note_color(), global_position, player))


func _draw() -> void:
	# A diamond (a square on its corner), spun and bobbing so it reads as a floating,
	# takeable thing — a silhouette nothing else in the world shares (§6, D-M4-7).
	# Both animations are applied to the drawn points only; the node stays still.
	var bob := Vector2(0.0, sin(_t * bob_speed) * bob_amplitude)
	var spin := _t * spin_speed
	var points := PackedVector2Array()
	for k in 4:
		var a := spin + float(k) * TAU / 4.0
		points.append(bob + Vector2(cos(a), sin(a)) * draw_radius)
	draw_colored_polygon(points, _note_color())
	# Closed outline: repeat the first point so the polyline seals the last edge.
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, EnvPalette.with_alpha("ink", 0.5), 1.0)
