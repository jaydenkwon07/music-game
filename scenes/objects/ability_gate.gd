class_name AbilityGate
extends Node2D
## A note-gated passage (spec §3.1). A physical blocker over an opening or an internal
## corridor that lifts the instant the player owns `required_note` — the grey-box stand-in
## for the note ability that will animate the crossing in M11. Ownership is the source of
## truth (NoteInventory is an autoload that persists across room re-instancing), so unlike a
## melody Door this needs no WorldState: it just re-checks `has()` on _ready.
##
## No `space` interaction and no melody: it is not an Interactable. It opens on ownership.

@export var required_note: String = ""
## Into the room, like room.gd's `inward`. Reserved for M10 art orientation; unused in grey-box.
@export var facing: Vector2i = Vector2i(0, 1)
@export var slab_size: Vector2 = Vector2(72.0, 90.0)

var _blocker: CollisionShape2D


func _ready() -> void:
	_add_blocker()
	if NoteInventory.has(required_note):
		_open()
	else:
		NoteInventory.note_collected.connect(_on_note_collected)


func _on_note_collected(note_id: String) -> void:
	if note_id == required_note:
		_open()


func _open() -> void:
	if _blocker != null:
		_blocker.set_deferred("disabled", true)


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	_blocker = CollisionShape2D.new()
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)
