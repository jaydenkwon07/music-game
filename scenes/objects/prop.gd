class_name Prop
extends Node2D
## A small decorative detail prop (M5 Step 5e): a rubble pile. Purely presentational — no
## collision, no light, no interaction — so it never touches the frozen geometry, the validator
## or the seal test. Drawn FLAT in palette colours (§3) and lit by the room's existing lights
## like the tiles; props don't emit, so the doors stay the brightest things (§5.4). Its exact
## shape is a deterministic spatial hash of its cell, never RNG, so a re-instanced room paints
## identically (§5, §10). It passes the black-on-white silhouette test (§6): a low lumpy mass,
## not a pickup, chime, door or the player. Finer detail (cracks, decals) is deferred to a
## later pass. Provisional art, like all of M5.

## Seeds the deterministic shape (set from the prop's grid cell by room.gd) so like props differ.
@export var seed_xy: Vector2i = Vector2i.ZERO
## The tile size props are sized against.
@export var unit: float = 30.0


func _draw() -> void:
	_draw_rubble()


# Deterministic 0..1 from the cell seed and a channel index — a spatial hash, not RNG (§5).
func _rand(channel: int) -> float:
	var h := absi((seed_xy.x * 73856093) ^ (seed_xy.y * 19349663) ^ (channel * 83492791))
	return float(h % 1000) / 1000.0


# A low pile of a few angular stones: darker bodies with one lit chip, so value gives the form.
func _draw_rubble() -> void:
	var shadow := EnvPalette.color("rock_shadow")
	var mid := EnvPalette.color("rock_mid")
	var high := EnvPalette.color("rock_high")
	_stone(Vector2(-0.22, 0.08) * unit, 0.20 * unit * (0.8 + 0.4 * _rand(1)), shadow, 10)
	_stone(Vector2(0.20, 0.11) * unit, 0.17 * unit * (0.8 + 0.4 * _rand(2)), shadow, 20)
	_stone(Vector2(0.0, -0.05) * unit, 0.24 * unit * (0.8 + 0.4 * _rand(3)), mid, 30)
	_stone(Vector2(0.06, -0.14) * unit, 0.10 * unit, high, 40)  # a small lit chip on top


# An irregular ~pentagon stone, vertices jittered deterministically off the cell seed.
func _stone(center: Vector2, r: float, col: Color, channel: int) -> void:
	var pts := PackedVector2Array()
	var n := 5
	for k in n:
		var ang := TAU * float(k) / float(n)
		var rr := r * (0.7 + 0.5 * _rand(channel + k))
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
