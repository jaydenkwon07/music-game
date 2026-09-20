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

## The drawn character (M5 Step 2d), procedural and static with 8-way facing (owner
## calls). A small humanoid — the ONLY character silhouette in the game (spec §8) —
## whose size sets the scale every other object is measured against, so these are the
## reference numbers, tuned by feel (§10). Drawn FLAT in palette values, no baked light
## (§8a): the PointLight2D above does the lighting. The node's origin is the character's
## centre, so light, camera and collision all stay aligned.
@export var head_radius: float = 6.0
@export var head_offset: float = 8.0     ## head centre this far above the origin
@export var head_lean: float = 2.5       ## how far the head leans toward the facing
@export var body_width: float = 15.0
@export var body_height: float = 18.0
@export var body_offset: float = 4.0     ## body centre this far below the origin

var facing: Vector2 = Vector2.DOWN
var _light: PointLight2D


func _ready() -> void:
	# Interactables detect the player body by this group; the Interactor turns
	# `interact` into the single world verb. Added in code to avoid touching the
	# scene file, matching how main.gd instantiates its scaffolding.
	add_to_group("player")
	add_child(Interactor.new())
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
		if facing != input_vector:
			facing = input_vector
			queue_redraw()  # the figure re-orients only when the direction changes
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


## The character: an oval torso and a head that leans toward the facing, with eyes on
## the side we look toward — hidden when facing away (up), so the figure reads as turned
## around. Flat "player" near-white so it stays the brightest thing in the cold open
## (§3.3); the only ink is the eyes, a feature and not shading. Static — no walk cycle
## yet (owner call); the 8-way read comes from the lean and the eyes alone.
func _draw() -> void:
	var skin := EnvPalette.color("player")
	var f := facing.normalized()
	if f == Vector2.ZERO:
		f = Vector2.DOWN
	draw_colored_polygon(_ellipse(Vector2(0.0, body_offset), body_width * 0.5, body_height * 0.5), skin)
	var head := Vector2(0.0, -head_offset) + f * head_lean
	draw_circle(head, head_radius, skin)
	if f.y > -0.5:  # we can see the face
		var ink := EnvPalette.color("ink")
		var eye_c := head + f * (head_radius * 0.35)
		var perp := Vector2(-f.y, f.x) * (head_radius * 0.45)
		var eye_r := maxf(1.0, head_radius * 0.22)
		draw_circle(eye_c + perp, eye_r, ink)
		draw_circle(eye_c - perp, eye_r, ink)


## An ellipse as a filled polygon (Godot has no rounded-rect primitive). Cheap enough
## to rebuild each redraw, and redraws only happen when the facing changes.
func _ellipse(center: Vector2, rx: float, ry: float, segments: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := float(i) / float(segments) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
