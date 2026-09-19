class_name MelodyChime
extends Interactable
## The world's clue delivery (design doc §3.6, Q5; owner's chosen vector, D-M3-2).
## Strike it with `space` and it plays a door's melody through the existing synth
## and pulses each note's colour in order — content lives here, so the door itself
## can drop to showing only structure (D-M3-3). Re-strikeable any time, so the
## player re-hears a clue on demand and no melody journal is needed in M3.
##
## Configured with only a melody id (§3): the notes and their colours resolve
## through MelodyLibrary and NoteRegistry. It fires no world effect and makes no
## gameplay decision — it plays notes in the overworld, where MelodyLock is not
## armed, so it can never advance a door. Presentational + audio only, no new art.

@export var melody_id: String = ""
## Silhouette (§6, D-M4-7): a hanging vertical bar with a top mount, struck-looking
## and deliberately NOT round, so a chime can never be mistaken for a takeable
## pickup (a floating diamond) in the dark or colourblind. Vertical is the whole
## point — that read is what a bare circle destroyed during M3 testing.
@export var bar_width: float = 9.0
@export var bar_height: float = 39.0
@export var mount_width: float = 21.0
@export var mount_height: float = 6.0
## How far the sounding "sound wave" ring clears the bar when the chime is struck.
@export var pulse_ring_radius: float = 30.0
## Seconds per beat; a note's on-screen/audible dwell is this times its rhythm.
@export var beat: float = 0.32
## Seconds a single note's colour pulse lasts.
@export var pulse_time: float = 0.3
## The chime carries its own light (§5.2, §5.4): a dim cool glow at rest so it
## announces itself before terrain, pulsing up in each note's colour as it plays.
@export var light_radius: float = 45.0
@export var light_base_energy: float = 0.25
@export var light_pulse_energy: float = 0.6

var _light: PointLight2D

# The colour pulse tracks its own phase, not a bare alpha (§10 envelope trap): a
# fresh note sets _pulse_color and _pulse_t together, and _pulse_t only counts
# down, so "just struck" is never confused with "faded out".
var _pulse_color: Color = Color.TRANSPARENT
var _pulse_t: float = 0.0
## Bumped on each strike; an in-flight sequence bails when it sees a newer one.
var _generation: int = 0


func _ready() -> void:
	super._ready()
	# Dim, cool, steady at rest so the chime is findable in the dark (§5.4).
	_light = Lighting.make_light(light_radius, light_base_energy, EnvPalette.color("rock_high"), false)
	add_child(_light)
	set_process(false)


## Always available: the clue can be re-heard as often as the player likes.
func can_interact() -> bool:
	return true


func interact(_player: Node2D) -> void:
	_play_sequence()


func _play_sequence() -> void:
	var midis := MelodyLibrary.get_midi(melody_id)
	if midis.is_empty():
		return
	var rhythm: Array = MelodyLibrary.get_melody(melody_id).get("rhythm", [])
	_generation += 1
	var gen := _generation
	for i in midis.size():
		# A newer strike superseded this playback — stop cleanly.
		if gen != _generation:
			return
		var midi := int(midis[i])
		NoteBus.play_note(midi, global_position)
		_pulse_color = NoteRegistry.color_for_midi(midi)
		_pulse_t = pulse_time
		_light.color = _pulse_color
		set_process(true)
		queue_redraw()
		var beats: float = float(rhythm[i]) if i < rhythm.size() else 1.0
		await get_tree().create_timer(beat * beats).timeout


func _process(delta: float) -> void:
	if _pulse_t > 0.0:
		_pulse_t = maxf(_pulse_t - delta, 0.0)
		# Light brightest at onset, easing back toward the resting glow.
		var intensity := _pulse_t / pulse_time if pulse_time > 0.0 else 0.0
		_light.energy = lerpf(light_base_energy, light_pulse_energy, intensity)
		queue_redraw()
	else:
		# Back to the resting cool glow between clues.
		_light.color = EnvPalette.color("rock_high")
		_light.energy = light_base_energy
		set_process(false)


func _draw() -> void:
	# The chime itself: a hanging bar in cool stone, deliberately not a note colour
	# so it reads as "a fixture that sings", not as a collectible. Its vertical
	# silhouette is the differentiator (§6, D-M4-7). Centred on the origin so it
	# aligns with the light and the interact point.
	var mount := Rect2(-mount_width * 0.5, -bar_height * 0.5 - mount_height, mount_width, mount_height)
	var bar := Rect2(-bar_width * 0.5, -bar_height * 0.5, bar_width, bar_height)
	# While struck, the bar rings: its stone tints toward the sounding note's colour,
	# brightest at onset. This is the only note colour the chime ever shows.
	var body := EnvPalette.color("rock_lit")
	if _pulse_t > 0.0 and pulse_time > 0.0:
		body = body.lerp(_pulse_color, _pulse_t / pulse_time)
	draw_rect(mount, EnvPalette.color("rock_high"), true)
	draw_rect(mount, EnvPalette.with_alpha("ink", 0.5), false, 1.0)
	draw_rect(bar, body, true)
	draw_rect(bar, EnvPalette.with_alpha("ink", 0.5), false, 1.0)

	# The pulse: a sound-wave ring in the sounding note's colour, clearing the bar,
	# brightest at onset.
	if _pulse_t > 0.0 and pulse_time > 0.0:
		var intensity := _pulse_t / pulse_time
		var ring := Color(_pulse_color, intensity)
		draw_arc(Vector2.ZERO, pulse_ring_radius, 0.0, TAU, 24, ring, 2.0)
