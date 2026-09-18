class_name NoteRing
extends Node2D
## An expanding, fading ring drawn where a note was played (§7.4).
##
## Purely presentational: it never decides what a note affects, and it frees
## itself when it finishes. Colour comes from the shared NoteColors mapping so
## every note visual speaks one language. Spawned by NoteVisuals, not built into
## any scene, so it lives in world space at the play position and stays put as
## the player moves on.

## Final radius in internal (640x360) pixels, and how long the whole animation
## lasts. Tune by feel. Radius/width doubled from M3 in the §4 migration.
@export var max_radius: float = 44.0
@export var duration: float = 0.5
@export var line_width: float = 4.0
## The ring also carries a light that travels with it and dies with it (§5.2):
## radius grows 0 → light_max_radius, energy fades light_energy → 0.
@export var light_max_radius: float = 90.0
@export var light_energy: float = 1.0

var _color: Color = Color.WHITE
var _age: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	z_index = 5  # above the room tiles, which sit at negative z


## Called once by the spawner before the ring is shown.
func setup(color: Color) -> void:
	_color = color
	# The light is the note's own colour, no shadows — a transient flash, and
	# several can overlap, so it stays cheap.
	_light = Lighting.make_light(0.1, light_energy, color, false)
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()
	# The light tracks the same ease as the ring, brightest at the attack.
	var t := _age / duration
	if _light != null:
		Lighting.set_radius(_light, maxf((1.0 - pow(1.0 - t, 3.0)) * light_max_radius, 0.1))
		_light.energy = light_energy * (1.0 - t)


func _draw() -> void:
	var t := _age / duration
	# Ease-out cubic: radius grows fast at the attack, slows as it fades, to
	# match the sound's shape (§7.4).
	var radius := (1.0 - pow(1.0 - t, 3.0)) * max_radius
	var c := _color
	c.a = 1.0 - t  # fade to transparent over the duration
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c, line_width, false)
