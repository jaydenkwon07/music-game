class_name ParticleBurst
extends Node2D
## A short-lived burst of small square particles (M4 Step 6, §9). Presentational
## only, self-freeing: used for the sparkle on a played note and the dust on a door
## unlock. Drawn by hand — small squares snapped to whole pixels — rather than via
## CPUParticles2D, so it reads crisp at 640×360 and never non-integer-scales a
## sprite (§9). Colour is passed in from the caller (a note colour), never authored.
##
## Spawn with the static factory, then add it as a child at the burst position:
##   parent.add_child(ParticleBurst.burst(color))
##   burst.position = where

## A single particle: world-space offset from the burst origin, its velocity, and
## how much life it has left in seconds.
class _Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float

@export var count: int = 8
@export var lifetime: float = 0.45
@export var speed: float = 70.0     ## initial px/sec, before drag
@export var drag: float = 4.0       ## per-second velocity decay; gives the ease-out
@export var particle_size: float = 2.0

var _color: Color = Color.WHITE
var _particles: Array = []


## Configure a burst in `color`; caller positions it and adds it to the tree.
static func burst(color: Color) -> ParticleBurst:
	var b := ParticleBurst.new()
	b._color = color
	return b


func _ready() -> void:
	z_index = 6  # above the note rings (z 5) and tiles
	for i in count:
		var p := _Particle.new()
		p.pos = Vector2.ZERO
		var angle := randf() * TAU
		p.vel = Vector2(cos(angle), sin(angle)) * speed * (0.4 + randf() * 0.6)
		p.life = lifetime * (0.6 + randf() * 0.4)
		_particles.append(p)


func _process(delta: float) -> void:
	var alive := false
	for p in _particles:
		if p.life <= 0.0:
			continue
		p.life -= delta
		p.vel = p.vel.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))
		p.pos += p.vel * delta
		alive = true
	if alive:
		queue_redraw()
	else:
		queue_free()


func _draw() -> void:
	for p in _particles:
		if p.life <= 0.0:
			continue
		var t := clampf(p.life / lifetime, 0.0, 1.0)
		var c := _color
		c.a = t
		# Snap to whole pixels so the dust never shimmers between grid cells.
		var origin: Vector2 = p.pos.round() - Vector2.ONE * (particle_size * 0.5)
		draw_rect(Rect2(origin, Vector2.ONE * particle_size), c, true)
