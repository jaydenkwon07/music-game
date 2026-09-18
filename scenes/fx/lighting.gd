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

static var _radial: GradientTexture2D


## The soft white→transparent radial falloff every light shares. Built once.
static func radial_texture() -> GradientTexture2D:
	if _radial != null:
		return _radial
	var grad := Gradient.new()
	# A soft shoulder: bright core, then a long fade to nothing at the edge, so the
	# light pool has no hard ring.
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0),
	])
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
