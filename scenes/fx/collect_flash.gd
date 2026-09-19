class_name CollectFlash
extends Node2D
## The pickup-collected flourish (M4 Step 6, §9): when a note is collected, its
## light lifts off the pickup and travels into the player, folding into the
## player's own (collection-grown) light. Makes "I gained this" legible without any
## UI. Presentational, self-freeing, and parented to the persistent World host so
## it outlives the pickup that spawned it (the pickup queue_free()s on collect).
##
## Colour is the collected note's colour, passed in — never authored here (§3).

@export var duration: float = 0.35
@export var start_radius: float = 30.0
@export var peak_radius: float = 55.0
@export var energy: float = 1.0

var _t: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _color: Color = Color.WHITE
var _light: PointLight2D


## Configure a flash in `color` travelling from `from_global` into `target`; the
## caller adds it to the World host.
static func spawn(color: Color, from_global: Vector2, target: Node2D) -> CollectFlash:
	var f := CollectFlash.new()
	f._from = from_global
	f._target = target
	f._color = color
	return f


func _ready() -> void:
	# Built here, not in the factory, so the export knobs (radius/energy) apply.
	_light = Lighting.make_light(start_radius, energy, _color, false)
	add_child(_light)
	global_position = _from


func _process(delta: float) -> void:
	_t += delta
	var p := clampf(_t / duration, 0.0, 1.0)
	if p >= 1.0:
		queue_free()
		return
	# Ease-in toward the player so it accelerates as it arrives and "folds in".
	var dest := _target.global_position if is_instance_valid(_target) else _from
	global_position = _from.lerp(dest, p * p)
	# Swell then collapse; energy holds, then fades out over the last stretch.
	Lighting.set_radius(_light, lerpf(peak_radius, start_radius * 0.2, p))
	_light.energy = energy * (1.0 - p * p)
