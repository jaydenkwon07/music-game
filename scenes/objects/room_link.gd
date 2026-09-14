class_name RoomLink
extends Area2D
## A room transition sitting in an unmarked gap (§6.4, design doc §3.7). Walking
## into it hands off to another room's named entry — the "connective tissue" that
## is deliberately free, unlike a door (§4.5).
##
## It does NOT reach for World directly: World is a scene node, not an autoload
## (§6.2), so it is not globally resolvable by name. The link emits
## `transition_requested`, the Room forwards it up, and World connects when it
## instances the room. No group lookup, no hardcoded path — both break the moment
## the scene tree is rearranged.
##
## Bounce-back guard (§6.4): a link starts DISARMED and arms after a short delay,
## and re-arms whenever the player leaves its area. So arriving on a link (the
## player materialises inside the far side's matching gap) does not immediately
## fire it back — it must be entered afresh after arming.

signal transition_requested(to_room: String, to_entry: String)

@export var to_room: String = ""
@export var to_entry: String = ""
## Trigger extent in pixels. About a tile, so the 10px player reliably crosses it.
@export var size: Vector2 = Vector2(16.0, 16.0)
## Seconds before a freshly-instanced link will fire, so an arrival gap does not
## bounce the player straight back.
@export var arm_delay: float = 0.3

var _armed: bool = false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Arm after a beat; if the player is standing on the arrival gap they will
	# have moved off (re-arming via body_exited) or the delay will have passed
	# with them still on it, in which case only a fresh entry re-fires.
	get_tree().create_timer(arm_delay).timeout.connect(_arm)


func _arm() -> void:
	_armed = true


func _on_body_entered(body: Node2D) -> void:
	if _armed and body.is_in_group("player"):
		transition_requested.emit(to_room, to_entry)


func _on_body_exited(body: Node2D) -> void:
	# Leaving the gap always re-arms it, so a return trip through the same gap
	# works even if the arm delay had not yet elapsed on arrival.
	if body.is_in_group("player"):
		_armed = true
