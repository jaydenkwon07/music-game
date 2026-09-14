class_name GrayTileSet
extends RefCounted
## The shared placeholder TileSet for M3's gray-box rooms (§6.7).
##
## Two tiles — a floor (no collision) and a wall (a full-tile collision polygon)
## — on one physics layer. Built in code so the whole slice runs and is verifiable
## without an in-editor authoring step; the tile size is a parameter here, and the
## Room reads it back from the TileSet rather than hardcoding it (§5.2), so a real
## editor-authored TileSet with real art can replace this at M5 with no other
## change. Deliberately flat gray: M3 is layout, not art (§1).

const FLOOR_ATLAS := Vector2i(0, 0)
const WALL_ATLAS := Vector2i(1, 0)
const SOURCE_ID := 0

const FLOOR_COLOR := Color(0.13, 0.13, 0.16)
const WALL_COLOR := Color(0.28, 0.26, 0.32)


## A two-tile gray TileSet with `tile_px`-square tiles. The wall tile carries a
## full-tile collision polygon on physics layer 0; the floor tile has none.
static func build(tile_px: int) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_px, tile_px)
	tile_set.add_physics_layer()  # layer 0, default collision layer/mask

	var source := TileSetAtlasSource.new()
	source.texture = _build_texture(tile_px)
	source.texture_region_size = Vector2i(tile_px, tile_px)
	# The source must belong to the TileSet before its tile data knows about the
	# TileSet's physics layers — otherwise setting collision below indexes a layer
	# that the tile data cannot see yet.
	tile_set.add_source(source, SOURCE_ID)
	source.create_tile(FLOOR_ATLAS)
	source.create_tile(WALL_ATLAS)

	# The wall gets a square collision polygon; points are relative to the tile
	# centre, so a full tile is ±half on each axis.
	var half := float(tile_px) * 0.5
	var wall := source.get_tile_data(WALL_ATLAS, 0)
	wall.set_collision_polygons_count(0, 1)
	wall.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]))

	return tile_set


## A 2×1 atlas: floor swatch on the left, wall swatch on the right.
static func _build_texture(tile_px: int) -> ImageTexture:
	var img := Image.create(tile_px * 2, tile_px, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, tile_px, tile_px), FLOOR_COLOR)
	img.fill_rect(Rect2i(tile_px, 0, tile_px, tile_px), WALL_COLOR)
	return ImageTexture.create_from_image(img)
