class_name Lighting
extends RefCounted
## Shared factory for the M4 lighting model (§5). Every light in the game is a
## PointLight2D with the one soft radial gradient texture built here, blended
## ADDITIVE so a lit surface returns toward its true palette value rather than
## being tinted by the light (§5.1). Pure helper: no nodes of its own, no state
## beyond the cached texture — callers own the lights they make.
##
## Radius is expressed in pixels; the texture is TEX_SIZE square, so a light's lit
## reach is TEX_SIZE/2 * texture_scale, and texture_scale = radius / (TEX_SIZE/2).

const TEX_SIZE := 256

## How many hard steps the radial falloff is quantised into (M5 Step 3a). The whole
## point is that the fade reads as BANDS of the rock ramp, not a smooth PNG blur —
## the one thing on screen that would otherwise not be made of pixels. This is a feel
## judgment (spec §12): ~3 is a strong stylistic statement, ~5 is subtle. Set it
## before the first light is built (i.e. at boot); the texture is cached on first use.
static var band_count: int = 5

static var _radial: GradientTexture2D


## The banded white→transparent radial falloff every light shares. Built once. Uses
## CONSTANT gradient interpolation so each band is a flat step, giving hard concentric
## rings of added light rather than a continuous blur.
static func radial_texture() -> GradientTexture2D:
	if _radial != null:
		return _radial
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var n: int = maxi(1, band_count)
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	# Even steps from a flat bright core to a transparent outer band, so the light
	# fully fades before the texture edge (the outermost band is alpha 0).
	for k in n:
		offsets.append(float(k) / float(n))
		var a: float = 1.0 if n == 1 else 1.0 - float(k) / float(n - 1)
		colors.append(Color(1.0, 1.0, 1.0, a))
	grad.offsets = offsets
	grad.colors = colors
	_radial = GradientTexture2D.new()
	_radial.gradient = grad
	_radial.width = TEX_SIZE
	_radial.height = TEX_SIZE
	_radial.fill = GradientTexture2D.FILL_RADIAL
	_radial.fill_from = Vector2(0.5, 0.5)
	_radial.fill_to = Vector2(1.0, 0.5)  # edge at radius = half the texture
	return _radial


## A configured additive PointLight2D. `radius_px` is the lit reach from centre.
static func make_light(radius_px: float, energy: float, color: Color, shadows: bool = false) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.texture_scale = radius_px / float(TEX_SIZE / 2)
	light.energy = energy
	light.color = color
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = shadows
	return light


## Re-aim an existing light at a new radius without rebuilding it (the player's
## light grows with collection, §5.3).
static func set_radius(light: PointLight2D, radius_px: float) -> void:
	light.texture_scale = radius_px / float(TEX_SIZE / 2)
