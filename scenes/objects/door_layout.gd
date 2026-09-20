class_name DoorLayout
extends RefCounted
## Pure orientation maths for a door's art and gems (M5 Step 5b). No nodes, no autoloads —
## so the facing conventions are unit-tested without the engine. A door faces the ROOM: the
## `facing` unit is room.gd's `inward` (N door → south (0,1), E door → west (-1,0)). Both the
## brass-pipe leaf and the gem bar are laid out in an (across, depth) frame this owns, so one
## drawing path serves every edge — DoorArt and DoorGems never branch on N-vs-E themselves.

## Unit vector ALONG the opening (perpendicular to facing): the axis gems and pipes run on.
static func across(facing: Vector2i) -> Vector2:
	return Vector2(absi(facing.y), absi(facing.x))


## The slab's extent ALONG the facing axis (its depth into the corridor). slab_size is
## authored across×depth for a vertical (N/S) door; a horizontal (E/W) door swaps them.
static func depth_extent(facing: Vector2i, slab_size: Vector2) -> float:
	return slab_size.x if facing.x != 0 else slab_size.y


## The slab's extent ACROSS the opening (the span the pipes/gems sit within).
static func across_extent(facing: Vector2i, slab_size: Vector2) -> float:
	return slab_size.y if facing.x != 0 else slab_size.x


## Centre of the gem row: the door origin pushed onto the ROOM-facing side by half the
## slab depth plus a margin, so the bar sits just inside the room, clear of the leaf.
static func gem_row_center(facing: Vector2i, slab_size: Vector2, margin: float) -> Vector2:
	return Vector2(facing) * (depth_extent(facing, slab_size) * 0.5 + margin)


## Gem i of `total`, laid out along `across`, centred on the row.
static func gem_position(i: int, total: int, facing: Vector2i, slab_size: Vector2, margin: float, spacing: float) -> Vector2:
	var start := -float(total) * spacing * 0.5 + spacing * 0.5
	return gem_row_center(facing, slab_size, margin) + across(facing) * (start + float(i) * spacing)
