extends Node
## Runtime polyphonic synth (§7.1).
##
## Generates tones with AudioStreamGenerator rather than playing sample files:
## pitch comes from NoteNames.to_frequency(), so tuning is exact by construction
## and nothing needs re-recording when the palette changes. Real instrument
## samples can replace this later behind NoteBus — listeners never know.
##
## Godot note: AudioStreamGenerator hands us a raw playback buffer. We push
## audio frames into it ourselves each _process; mixing all voices in one buffer
## (rather than one AudioStreamPlayer per voice) is what lets us scale the sum
## to prevent clipping, which the per-player bus mixer could not do for us.
##
## Audio always plays, even in the instrument state (§6): this deliberately does
## NOT check NoteBus.effects_enabled() — only gameplay effects do.

const MIX_RATE := 44100.0
## Seconds of generator buffer. This is the play-to-hear latency: _process
## keeps the buffer full, so a new note waits behind whatever is already queued.
## It is also the dropout margin — the buffer must outlast one frame (~16ms at
## 60fps) or it empties between fills and crackles. 40ms trades a safe ~2.4
## frames of headroom for a responsive feel. Lower toward ~0.02 if the machine
## holds it without crackle; raise if you hear dropouts.
const BUFFER_LENGTH := 0.04
const MAX_VOICES := 8

## Per-voice amplitude before mixing. With sqrt-scaling a full chord peaks at
## sqrt(MAX_VOICES) * voice_gain * master_gain, kept under 1.0 to avoid clipping.
@export var voice_gain: float = 0.22
## Master level after mixing. Tune by feel.
@export var master_gain: float = 0.9
## Attack ramp in seconds. A few ms removes the click at note onset.
@export var attack: float = 0.006
## Exponential decay time constant in seconds. Larger = longer sustain.
@export var decay_tau: float = 0.28

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

# Parallel voice arrays, indexed 0..MAX_VOICES-1.
var _active: Array[bool] = []
var _phase: Array[float] = []   # cycles, wrapped to [0, 1)
var _step: Array[float] = []    # cycles advanced per sample
var _age: Array[float] = []     # seconds since onset

# Applied mix divisor, eased toward sqrt(active) so a starting or ending voice
# doesn't jump the scale factor of the notes already sounding and click.
var _divisor: float = 1.0


func _ready() -> void:
	for _i in MAX_VOICES:
		_active.append(false)
		_phase.append(0.0)
		_step.append(0.0)
		_age.append(0.0)

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)
	_player.play()  # must play() before the playback buffer exists
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

	NoteBus.note_played.connect(_on_note_played)


func _on_note_played(midi: int, _source: Vector2) -> void:
	if midi < 0:
		return
	_trigger(NoteNames.to_frequency(midi))


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var dt := 1.0 / MIX_RATE
	for _i in _playback.get_frames_available():
		_playback.push_frame(_next_frame(dt))


func _next_frame(dt: float) -> Vector2:
	var sum := 0.0
	var active := 0
	for v in MAX_VOICES:
		if not _active[v]:
			continue
		var env := _envelope(_age[v])
		# env is legitimately 0 at the very start of the attack ramp (age 0), so
		# only treat 0 as "faded out, free the voice" once past the attack.
		if env <= 0.0 and _age[v] >= attack:
			_active[v] = false
			continue
		sum += sin(_phase[v] * TAU) * env * voice_gain
		_phase[v] = fmod(_phase[v] + _step[v], 1.0)
		_age[v] += dt
		active += 1

	_divisor = lerp(_divisor, sqrt(float(max(active, 1))), 0.05)
	var out := (sum / _divisor) * master_gain
	return Vector2(out, out)


## Amplitude 0..~1: linear attack, then exponential decay. Returns exactly 0
## once the tail is inaudible, which frees the voice.
func _envelope(age: float) -> float:
	if age < attack:
		return age / attack
	var a := exp(-(age - attack) / decay_tau)
	return a if a > 0.001 else 0.0


func _trigger(freq: float) -> void:
	var v := _free_voice()
	_active[v] = true
	_phase[v] = 0.0
	_step[v] = freq / MIX_RATE
	_age[v] = 0.0


## A free voice, or the oldest one stolen, so a 9th note isn't dropped silently.
func _free_voice() -> int:
	for v in MAX_VOICES:
		if not _active[v]:
			return v
	var oldest := 0
	for v in range(1, MAX_VOICES):
		if _age[v] > _age[oldest]:
			oldest = v
	return oldest
