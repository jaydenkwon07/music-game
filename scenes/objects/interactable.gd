class_name Interactable
extends Area2D
## The one interface for anything the player interacts with via `space`: note
## pickups now, and doors / NPCs / hints later (M3). An Interactable detects the
## player entering its radius and, while in range, joins the IN_RANGE_GROUP so the
## player's Interactor can find it; pressing `interact` fires the nearest one's
## interact().
##
## Subclasses override interact() (what happens) and, if their availability
## changes, can_interact() (whether they respond right now — e.g. an already-
## collected pickup or an opened door). The base is pure plumbing: no game
## behaviour, no pitch, no melody (§3).

## Name of the group holding every Interactable the player is currently inside.
## The Interactor reads this on `interact` rather than holding references (§4:
## prefer signals/groups over cross-system node references).
const IN_RANGE_GROUP := "interactable_in_range"

## How close the player must be for this to be interactable, in pixels. Doubled
## from M3's 12 in the §4 resolution migration (world units doubled).
@export var radius: float = 24.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		add_to_group(IN_RANGE_GROUP)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		remove_from_group(IN_RANGE_GROUP)


## Whether this responds to interact right now. Override to gate on state; the
## Interactor skips any in-range Interactable that returns false.
func can_interact() -> bool:
	return true


## What happens when the player interacts. Override in the subclass; the base
## does nothing on purpose.
func interact(_player: Node2D) -> void:
	pass
