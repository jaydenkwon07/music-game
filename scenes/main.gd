extends Control
## Root of the render pipeline (§6, D-M4-4). The world renders into a FIXED
## 640×360 SubViewport (the pixel-art internal resolution, §4), and the Display
## TextureRect scales that up to fill the window at any size — windowed or
## fullscreen — letterboxed, never distorted. Post-process shaders (bloom,
## vignette) attach to the Display later, so they run at output resolution, after
## the upscale (never on the 640×360 buffer, which would make bloom blocky).
##
## A bare SubViewport receives no input on its own (unlike a SubViewportContainer),
## so keyboard/action input is forwarded here explicitly. Movement is safe either
## way — it polls Input directly — but notes, interact, octave and Tab go through
## _unhandled_input, which must reach the world inside the viewport.

@onready var _viewport: SubViewport = $GameViewport
@onready var _display: TextureRect = $Display


func _ready() -> void:
	_display.texture = _viewport.get_texture()


func _unhandled_input(event: InputEvent) -> void:
	if _viewport != null:
		_viewport.push_input(event)
