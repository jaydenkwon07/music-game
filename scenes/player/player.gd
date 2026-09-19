extends CharacterBody2D
## 8-directional movement. No abilities, no notes — M0 is movement only.

## Pixels per second. At 960x540 the screen is 32 tiles of 30px; 240 crosses it in
## about four seconds. Scaled ×1.5 from 160 at the 640→960 resolution step (tiles
## 20→30px), so the world plays at the same on-screen pace. The single most
## important number to tune by feel.
@export var max_speed: float = 240.0

## Seconds to reach full speed from rest, and to stop from full speed.
## Zero gives instant, Undertale-ish response. A little smoothing usually
## feels better on a keyboard; start at 0.05 and argue with it.
@export var acceleration_time: float = 0.05
@export var deceleration_time: float = 0.05

## The player's light grows with collection (§5.3, D-M4-5): Pillar 2 made
## mechanical — they see more of the world as they accumulate, and the cold open
## is genuinely dark because they genuinely have nothing. Radius ramps from
## LIGHT_MIN (zero notes) to LIGHT_MAX (a full twelve), by owned pitch classes.
@export var light_min_radius: float = 75.0
@export var light_max_radius: float = 180.0
@export var light_energy: float = 0.8
const LIGHT_FULL_COLLECTION := 12

## Camera follow-lag (§9): the Camera2D's position_smoothing_speed — higher trails
## tighter, 0 disables it (the camera locks to the player). The viewport pixel-snaps
## (main.tscn), so the trail doesn't shimmer; World.reset_smoothing() on room-enter
## keeps a teleport from smearing across the map. Tune by feel.
@export var camera_follow_speed: float = 8.0

var facing: Vector2 = Vector2.DOWN
var _light: PointLight2D


func _ready() -> void:
	# Interactables detect the player body by this group; the Interactor turns
	# `interact` into the single world verb. Added in code to avoid touching the
	# scene file, matching how main.gd instantiates its scaffolding.
	add_to_group("player")
	add_child(Interactor.new())
	# The player is the palette's near-white (§3.3): the brightest thing on screen
	# when unlit, so in the cold open they read as the only thing. Sourced from
	# EnvPalette, never a hex literal here (§3).
	var body := get_node_or_null("Body") as ColorRect
	if body != null:
		body.color = EnvPalette.color("player")
	# The player carries their own light (§5.2), warm-white and shadow-casting so
	# walls fall dark around them, and it grows as they collect (§5.3).
	_light = Lighting.make_light(light_min_radius, light_energy, EnvPalette.color("bright"), true)
	add_child(_light)
	NoteInventory.note_collected.connect(_on_note_collected)
	_refresh_light()
	# Camera follow-lag (§9): a small trail behind the player. World clamps it to the
	# room bounds and resets smoothing on transition.
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = camera_follow_speed > 0.0
		camera.position_smoothing_speed = camera_follow_speed


func _on_note_collected(_note_id: String) -> void:
	_refresh_light()


## Radius scales linearly with owned pitch classes. slot_count() is the count the
## inventory tracks today; when an owned-vs-equipped store exists it becomes the
## owned total (§6, "owning is not wielding") with no change here.
func _refresh_light() -> void:
	var t := clampf(float(NoteInventory.slot_count()) / float(LIGHT_FULL_COLLECTION), 0.0, 1.0)
	Lighting.set_radius(_light, lerpf(light_min_radius, light_max_radius, t))


func _physics_process(delta: float) -> void:
	# Instrument state suspends movement (§6): notes become musical only, the world
	# keeps running behind the overlay, and the movement keys are free to double as
	# piano keys because nothing reads them here. Model on Ocarina of Time.
	if NoteBus.instrument_state_active:
		velocity = Vector2.ZERO
		return

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
