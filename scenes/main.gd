extends Control
## Root of the render pipeline (§6, D-M4-4). The world renders into a FIXED
## 960×540 SubViewport (the pixel-art internal resolution, §4). Scaling that to
## the window is TWO stages (M5 Step 0, CLAUDE.md §1):
##
##   GameViewport (960×540, nearest content)
##     → Prescale SubViewport: nearest-neighbour upscale to the LARGEST INTEGER
##       multiple of 960×540 that fits the window — pixel shape is fixed here
##     → Display TextureRect: bilinear resample of THAT already-correct image to
##       the window, letterboxed to keep aspect
##
## The integer step means every source pixel is a clean square block; the
## fractional step only ever resamples an image that already has correct pixel
## shape. So 1440p (a ×2.67 target that is neither integer-clean nor 16:9-friendly
## to letterbox — black would eat 44% of the screen) neither shimmers during
## movement nor gets letterboxed away. At 1080p (×2) and 4K (×4) the second stage
## is an exact no-op and the result is pixel-perfect.
##
## Post-process shaders (bloom, vignette) attach to the Display later, so they run
## at OUTPUT resolution, after the upscale — never on the 960×540 buffer, which
## would make bloom blocky (M5 Step 3b).
##
## A bare SubViewport receives no input on its own (unlike a SubViewportContainer),
## so keyboard/action input is forwarded here explicitly via push_input.

const BASE_SIZE := Vector2i(960, 540)

## Post-process shader for the Display, run at output resolution after the upscale
## (M5 Step 3b). Vignette only; bloom is deliberately off (spec §12).
const VIGNETTE_SHADER := preload("res://scenes/fx/vignette.gdshader")

@onready var _viewport: SubViewport = $GameViewport
@onready var _prescale: SubViewport = $Prescale
@onready var _prescale_rect: TextureRect = $Prescale/PrescaleRect
@onready var _display: TextureRect = $Display


func _ready() -> void:
	_prescale_rect.texture = _viewport.get_texture()
	_display.texture = _prescale.get_texture()
	var post := ShaderMaterial.new()
	post.shader = VIGNETTE_SHADER
	_display.material = post
	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()


## Size the Prescale viewport to the largest whole multiple of the internal
## resolution that still fits the window. The PrescaleRect fills it via anchors,
## so only the viewport size is set here.
func _update_scale() -> void:
	var win: Vector2i = get_tree().root.size
	var factor: int = maxi(1, mini(win.x / BASE_SIZE.x, win.y / BASE_SIZE.y))
	_prescale.size = BASE_SIZE * factor


func _unhandled_input(event: InputEvent) -> void:
	if _viewport != null:
		_viewport.push_input(event)
