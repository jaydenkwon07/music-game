class_name NoteRing
extends Node2D
## An expanding, fading ring drawn where a note was played (§7.4).
##
## Purely presentational: it never decides what a note affects, and it frees
## itself when it finishes. Colour comes from the shared NoteColors mapping so
## every note visual speaks one language. Spawned by NoteVisuals, not built into
## any scene, so it lives in world space at the play position and stays put as
## the player moves on.

## Final radius in internal (320x180) pixels, and how long the whole animation
## lasts. Tune by feel.
@export var max_radius: float = 22.0
@export var duration: float = 0.5
@export var line_width: float = 2.0

var _color: Color = Color.WHITE
var _age: float = 0.0


func _ready() -> void:
	z_index = 5  # above the room tiles, which sit at negative z


## Called once by the spawner before the ring is shown.
func setup(color: Color) -> void:
	_color = color


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / duration
	# Ease-out cubic: radius grows fast at the attack, slows as it fades, to
	# match the sound's shape (§7.4).
	var radius := (1.0 - pow(1.0 - t, 3.0)) * max_radius
	var c := _color
	c.a = 1.0 - t  # fade to transparent over the duration
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c, line_width, false)
