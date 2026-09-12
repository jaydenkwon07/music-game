extends CharacterBody2D
## 8-directional movement. No abilities, no notes — M0 is movement only.

## Pixels per second. At 320x180 the screen is ~20 tiles wide, so 60 crosses
## it in about five seconds. Tune this by feel; it is the single most
## important number in the game right now.
@export var max_speed: float = 80.0

## Seconds to reach full speed from rest, and to stop from full speed.
## Zero gives instant, Undertale-ish response. A little smoothing usually
## feels better on a keyboard; start at 0.05 and argue with it.
@export var acceleration_time: float = 0.05
@export var deceleration_time: float = 0.05

var facing: Vector2 = Vector2.DOWN


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# get_vector normalises for us, so diagonals are not faster than cardinals.
	if input_vector != Vector2.ZERO:
		facing = input_vector
		velocity = velocity.move_toward(
			input_vector * max_speed,
			_rate(acceleration_time) * delta
		)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, _rate(deceleration_time) * delta)

	move_and_slide()


func _rate(seconds: float) -> float:
	if seconds <= 0.0:
		return max_speed * 1000.0
	return max_speed / seconds
