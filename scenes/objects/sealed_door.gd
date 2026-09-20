class_name SealedDoor
extends Node2D
## A decorative, permanently-closed melody door (M5 Step 5c). Unlike Door it composes NO
## MelodyLock, melody or link (owner call, 2026-09-20) — it is pure presentation: the S exit
## of the Cistern, a FIVE-note door the player can't yet solve because notes 4–5 aren't held
## (and their categories aren't assigned, §9). It reuses DoorArt for the carved-stone +
## brass-pipe leaf and DoorLayout for orientation, so it reads as the same family as the real
## doors; it just shows five UNLIT sockets — the note COUNT and nothing about which notes
## (§6 "doors show structure, never content"). It never opens and is not Interactable, so
## `space` does nothing to it. A StaticBody2D blocker makes it a hard barrier: nothing lies
## behind it (the S corridor is a dead-end stub), and a sealed door should read as a wall.
## Colours by EnvPalette name (§3). Its faint self-light is a placeholder for 5d's light
## composition, which tunes every door light (the sealed one dimmer than a live door).

## Matches Door.slab_size so the sealed leaf is the same size as the real ones.
@export var slab_size: Vector2 = Vector2(72.0, 90.0)
## Into the room (room.gd's `inward`): the S door faces north (0,-1). Orients art + sockets.
@export var facing: Vector2i = Vector2i(0, -1)
## How many empty sockets — the door's note count. Five here (the act-2 door).
@export var socket_count: int = 5
## Match DoorGems' gem geometry so sockets sit in the same visual language as real gems.
@export var socket_radius: float = 8.0
@export var socket_margin: float = 15.0
## The door's own faint glow, so it's visible in the dark cave yet reads dimmer than a live
## door. 5d owns the final light composition; this is a deliberate placeholder.
@export var light_radius: float = 60.0
@export var light_energy: float = 0.22

var _art: DoorArt


func _ready() -> void:
	_add_blocker()
	_art = DoorArt.new()
	add_child(_art)          # drawn first (below), sockets drawn on top in _draw
	_art.configure(facing, slab_size)
	_add_light()
	queue_redraw()


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _add_light() -> void:
	var light := Lighting.make_light(light_radius, light_energy, EnvPalette.color("brass"), false)
	add_child(light)


func _spacing() -> float:
	return socket_radius * 2.0 + 6.0


## Five unlit sockets on the room-facing side, laid out along the opening via DoorLayout — the
## same seam and spacing the real doors' gems use. Drawn as empty stone settings (a dark recess
## with a carved rim), NO note hue and NO category, so they show the count and commit to nothing.
func _draw() -> void:
	for i in socket_count:
		var pos := DoorLayout.gem_position(i, socket_count, facing, slab_size, socket_margin, _spacing())
		draw_circle(pos, socket_radius, EnvPalette.color("rock_shadow"))  # dark empty recess
		draw_arc(pos, socket_radius, 0.0, TAU, 16, EnvPalette.color("rock_high"), 1.5)  # carved rim
