extends Node2D
## The persistent world host (§6.2). Replaces main.gd's room role: the player, the
## UI and the instrument overlay live here and survive room transitions, while the
## single active room is instanced under RoomHost and swapped on transition.
##
## World is a scene node, not an autoload — so RoomLinks reach it by forwarding a
## signal up through their Room rather than by a global lookup or a fixed path
## (§6.4). The camera is a follow-cam clamped to each room's bounds, which also
## removes the out-of-bounds void (§3.7, D-M3-5).

@onready var room_host: Node2D = $RoomHost
@onready var player: CharacterBody2D = $Player
@onready var debug_label: Label = $UI/DebugLabel

var _current_room: Room = null


func _ready() -> void:
	add_child(InstrumentOverlay.new())
	var s := RoomGraph.start()
	enter_room(str(s.get("room", "")), str(s.get("entry", "")))


## Swap to a room and place the player at one of its named entries. Freeing the
## old room and instancing the new one; safe to call from a transition signal
## because RoomLink → Room → here arrives deferred (see _on_transition_requested).
func enter_room(room_id: String, entry_id: String) -> void:
	if room_id.is_empty():
		push_error("World: enter_room called with no room id.")
		return
	if _current_room != null:
		_current_room.queue_free()
		_current_room = null

	var room := _instance_room(room_id)
	if room == null:
		return
	room_host.add_child(room)
	room.transition_requested.connect(_on_transition_requested)
	_current_room = room

	player.global_position = room.entry_position(entry_id)
	_apply_camera_limits(room.bounds())


func _instance_room(room_id: String) -> Room:
	var path := "res://scenes/rooms/%s.tscn" % room_id
	if not ResourceLoader.exists(path):
		push_error("World: no room scene at %s." % path)
		return null
	return (load(path) as PackedScene).instantiate() as Room


## A transition can fire from inside a RoomLink's body_entered, i.e. mid-physics —
## freeing the room (and that very link) then would crash. Defer the swap to the
## next idle so the current signal finishes first.
func _on_transition_requested(to_room: String, to_entry: String) -> void:
	enter_room.call_deferred(to_room, to_entry)


## Clamp the follow-cam to the room's bounds (§3.7). A room at or above the
## viewport in both dimensions reads as a fixed screen; a larger room scrolls.
func _apply_camera_limits(room_bounds: Rect2) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = int(room_bounds.position.x)
	camera.limit_top = int(room_bounds.position.y)
	camera.limit_right = int(room_bounds.end.x)
	camera.limit_bottom = int(room_bounds.end.y)
	# The player teleported; don't smear the camera across the whole map.
	camera.reset_smoothing()


func _process(_delta: float) -> void:
	debug_label.text = "%d x %d   layout: %s   room: %s" % [
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		InputConfig.Layout.keys()[InputConfig.current_layout],
		_current_room.room_id if _current_room != null else "-",
	]


func _unhandled_input(event: InputEvent) -> void:
	# Tab swaps movement layout. Temporary, until there is a settings menu.
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		var next := (
			InputConfig.Layout.ARROWS
			if InputConfig.current_layout == InputConfig.Layout.WASD
			else InputConfig.Layout.WASD
		)
		InputConfig.apply_layout(next)
