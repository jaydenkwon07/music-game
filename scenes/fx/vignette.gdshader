shader_type canvas_item;
// Post-process vignette on the Display, applied AFTER the upscale (M5 Step 3b): the
// spec is explicit that effects run at OUTPUT resolution, never on the 960×540 buffer.
// Darkens the corners so the eye settles centre-frame. Conservative by default and
// vignette-only — bloom stays off (spec §12), since a world built on an
// emptiness-to-fullness arc shouldn't be pushed to glow more.
//
// UV is 0–1 across the drawn image; distance is normalised so a corner reads ~1.0.
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.5;   // how dark the corners get
uniform float vignette_radius : hint_range(0.0, 1.2) = 0.72;  // where darkening begins

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dist = distance(UV, vec2(0.5)) / 0.70710678;
	float amt = smoothstep(vignette_radius, 1.0, dist) * vignette_amount;
	c.rgb *= (1.0 - amt);
	COLOR = c;
}
