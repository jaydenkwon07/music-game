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
@export var draw_radius: float = 5.0
## Seconds per beat; a note's on-screen/audible dwell is this times its rhythm.
@export var beat: float = 0.32
## Seconds a single note's colour pulse lasts.
@export var pulse_time: float = 0.3

# The colour pulse tracks its own phase, not a bare alpha (§10 envelope trap): a
# fresh note sets _pulse_color and _pulse_t together, and _pulse_t only counts
# down, so "just struck" is never confused with "faded out".
var _pulse_color: Color = Color.TRANSPARENT
var _pulse_t: float = 0.0
## Bumped on each strike; an in-flight sequence bails when it sees a newer one.
var _generation: int = 0


func _ready() -> void:
	super._ready()
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
		set_process(true)
		queue_redraw()
		var beats: float = float(rhythm[i]) if i < rhythm.size() else 1.0
		await get_tree().create_timer(beat * beats).timeout


func _process(delta: float) -> void:
	if _pulse_t > 0.0:
		_pulse_t = maxf(_pulse_t - delta, 0.0)
		queue_redraw()
	else:
		set_process(false)


func _draw() -> void:
	# The crystal itself: a small cool-gray diamond, deliberately not a note colour
	# so it reads as "a thing that sings", not as a note.
	var body := Color(0.42, 0.46, 0.58)
	draw_circle(Vector2.ZERO, draw_radius, body)
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.5), 1.0)

	# The pulse: a ring in the currently-sounding note's colour, brightest at onset.
	if _pulse_t > 0.0 and pulse_time > 0.0:
		var intensity := _pulse_t / pulse_time
		var ring := Color(_pulse_color, intensity)
		draw_arc(Vector2.ZERO, draw_radius + 2.5, 0.0, TAU, 24, ring, 1.5)
