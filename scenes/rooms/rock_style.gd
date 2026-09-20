class_name RockStyle
extends Resource
## Tunable look of the cave tileset (M5 Step 2b). The tuning surface for the whole
## cave: `room.gd` holds one of these (or the defaults) and hands it to
## RockTileSet.build. Edit the values here, assign a `.tres`, or tweak them in the
## inspector — none of it is baked into the drawing code.
##
## Colours are EnvPalette NAMES, never hex (§3, the one rule's environment
## corollary); an unknown name resolves to magenta so a typo shows. Tiles stay FLAT
## (no baked directional light — the PointLights do that, §8a). The value gap below
## is the deliverable: floor reads LIGHTER than rock so the room is legible without
## leaning on the outline (reference: dark walls, a lifted floor).

## Floor base — one to two ramp steps LIGHTER than the rock body (~1.7× its
## brightness is a starting point, spec 2b).
@export var floor_tone: String = "rock_shadow"
## Rock body base — dark, so outcrops and walls recede against the floor.
@export var rock_tone: String = "rock_deep"
## The wall-meets-floor contact seam: the darkest tone, laid where rock nears floor.
@export var seam_tone: String = "rock_void"

## Contact-seam width in px, from the rock/floor boundary inward (distance-field, so
## it also outlines corners). 0 removes the seam.
@export_range(0.0, 6.0, 0.1) var seam_px: float = 2.0
## Facet grit density per tile (flat value variation, not a light gradient).
@export_range(0, 16) var rock_facet_count: int = 5
@export_range(0, 16) var floor_pit_count: int = 6

## Corner bevels (M5 Step 2c): the leg length of the 45° cut at a rock corner, as a
## fraction of a cell. Equal legs, so the cut is always 45°, and at a full cell (1.0)
## consecutive convex corners join into one straight diagonal — the fix for the dome
## shoulders reading as staircases. Collision and the light occluder follow the same
## cut, so the slope is solid, not painted-on. A lone outcrop with four active corners
## becomes an octagon (partial) or a diamond (full) — that is the outcrop stress test,
## judged on `godot .`.
##
## Convex = outer corners (the shoulders); judge these first. Concave = inner corners,
## which a prior notch treatment turned to "chipped rock" (2c) — it defaults OFF so the
## shoulder judgment is not contaminated; raise it to try inner rounding.
@export_range(0.0, 1.0, 0.05) var bevel_convex: float = 1.0
@export_range(0.0, 1.0, 0.05) var bevel_concave: float = 0.0
