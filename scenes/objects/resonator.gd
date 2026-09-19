class_name Resonator
extends Node2D
## A block tuned to a palette SLOT (not a pitch, §3 corollary): play its note
## close by and it resonates in its colour; play the wrong one and it shrugs.
##
## This is the first thing in the game to gate on NoteBus.effects_enabled().
## In the instrument state a note is musical only (§6) — audio and visuals still
## play, but no world effect fires — so a resonator must go quiet there.

## Which palette slot this block answers to. Rewrite the palette JSON and it
## retunes with no code change.
@export var slot: int = 0
## Sizes/ranges scaled with the world across migrations (×1.5 at the 640→960 step).
@export var block_size: Vector2 = Vector2(60.0, 60.0)
## How close the play position must be for the block to hear the note, in pixels.
@export var hear_radius: float = 120.0

## Seconds the correct-note light and the wrong-note shake each last.
@export var light_time: float = 0.45
@export var shake_time: float = 0.2
@export var shake_pixels: float = 6.0

var _light: float = 0.0  # remaining light time, seconds
var _shake: float = 0.0  # remaining shake time, seconds


func _ready() -> void:
	NoteBus.note_played.connect(_on_note_played)


func _on_note_played(midi: int, source: Vector2) -> void:
	if midi < 0:
		return
	# The gate: no gameplay-visible effect while the world is in instrument state.
	if not NoteBus.effects_enabled():
		return
	if global_position.distance_to(source) > hear_radius:
		return
	if midi == NoteInventory.midi_for_slot(slot):
		_light = light_time
	else:
		_shake = shake_time
	queue_redraw()


func _process(delta: float) -> void:
	var busy := false
	if _light > 0.0:
		_light = maxf(_light - delta, 0.0)
		busy = true
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	var base := NoteRegistry.color_for_midi(NoteInventory.midi_for_slot(slot))
	# Dim at rest so the tuning colour still reads; brightens to full when struck.
	var lit := (_light / light_time) if light_time > 0.0 else 0.0
	var col := base.darkened(0.55).lerp(base, lit)

	var offset := Vector2.ZERO
	if _shake > 0.0 and shake_time > 0.0:
		# Small, decaying horizontal jitter — a dull "no", not a celebration.
		var phase := (1.0 - _shake / shake_time) * TAU * 3.0
		offset.x = sin(phase) * shake_pixels * (_shake / shake_time)

	var rect := Rect2(-block_size * 0.5 + offset, block_size)
	draw_rect(rect, col, true)
	draw_rect(rect, EnvPalette.with_alpha("ink", 0.5), false, 1.0)
