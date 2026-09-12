extends Node2D
## A gray box to walk around in. Built in code so M0 has no art dependency
## and no hand-authored tilemap to maintain.
##
## This is scaffolding, not level design. Rooms become real scenes with a
## TileMapLayer at M3, and this file gets deleted.

const TILE := 16

## Room size in tiles. 20x11 fills one 320x180 screen exactly.
@export var room_tiles: Vector2i = Vector2i(30, 18)

@export var floor_color: Color = Color(0.13, 0.13, 0.16)
@export var wall_color: Color = Color(0.28, 0.26, 0.32)
@export var pillar_color: Color = Color(0.22, 0.20, 0.26)


func _ready() -> void:
	_add_floor()
	_add_perimeter()
	_add_obstacles()


func spawn_point() -> Vector2:
	return Vector2(room_tiles.x, room_tiles.y) * TILE * 0.5


func _add_floor() -> void:
	var rect := ColorRect.new()
	rect.color = floor_color
	rect.size = Vector2(room_tiles) * TILE
	rect.z_index = -10
	add_child(rect)


func _add_perimeter() -> void:
	var w := room_tiles.x
	var h := room_tiles.y
	_add_wall(Rect2(0, 0, w, 1))              # top
	_add_wall(Rect2(0, h - 1, w, 1))          # bottom
	_add_wall(Rect2(0, 1, 1, h - 2))          # left
	_add_wall(Rect2(w - 1, 1, 1, h - 2))      # right


## A few blocks to bump into, so collision and diagonal sliding are visible.
func _add_obstacles() -> void:
	_add_wall(Rect2(6, 5, 3, 3), pillar_color)
	_add_wall(Rect2(20, 4, 2, 8), pillar_color)
	_add_wall(Rect2(12, 12, 6, 2), pillar_color)


## rect is given in tiles, not pixels.
func _add_wall(rect: Rect2, color: Color = wall_color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position * TILE

	var size := rect.size * TILE

	var visual := ColorRect.new()
	visual.color = color
	visual.size = size
	body.add_child(visual)

	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = size * 0.5
	body.add_child(collider)

	add_child(body)
