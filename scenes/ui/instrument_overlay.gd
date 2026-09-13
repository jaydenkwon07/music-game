class_name InstrumentOverlay
extends CanvasLayer
## A translucent scrim that fades in while the instrument state is active (§5.8).
## The world keeps rendering and running behind it — this is an overlay, not a
## scene change, modelled on Ocarina of Time: no fade to black, no loading, and
## cancel is instant and free.
##
## Instantiated in code by main.gd (avoids editing main.tscn). Sits on layer 1 so
## it composits over the layer-0 world; the scrim is translucent, so the note bar
## and debug readout still read through it.
##
## Envelope trap (§10): the fade tracks an explicit TARGET alpha and eases toward
## it, then stops. An alpha of 0 at the start of a fade-in is distinguished from 0
## at the end of a fade-out by the target, never by the current value alone.

## Scrim colour at full opacity. Cool and dark so the instrument state reads as a
## distinct mode. Tune by feel.
@export var scrim_color: Color = Color(0.05, 0.06, 0.12)
## Opacity when fully faded in. Low enough that the world stays visible behind it.
@export var max_alpha: float = 0.32
## Seconds for a full fade. Fast, so cancel feels instant (§5.8).
@export var fade_time: float = 0.12

var _scrim: ColorRect
var _alpha: float = 0.0
var _target_alpha: float = 0.0


func _ready() -> void:
	layer = 1
	_scrim = ColorRect.new()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(scrim_color, 0.0)
	add_child(_scrim)
	NoteBus.instrument_state_changed.connect(_on_instrument_state_changed)
	set_process(false)


func _on_instrument_state_changed(active: bool) -> void:
	_target_alpha = max_alpha if active else 0.0
	set_process(true)


func _process(delta: float) -> void:
	var step := (max_alpha / fade_time) * delta if fade_time > 0.0 else max_alpha
	_alpha = move_toward(_alpha, _target_alpha, step)
	_scrim.color = Color(scrim_color, _alpha)
	# Stop animating once the target is reached — the target, not the value, is
	# what says which end of the fade we are at.
	if is_equal_approx(_alpha, _target_alpha):
		_alpha = _target_alpha
		set_process(false)
