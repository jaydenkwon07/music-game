class_name NoteBar
extends Control
## The overworld note bar (§7.6): one slot per palette note along the bottom of
## the screen, colour first and note name second, flashing when that note plays.
##
## Presentational only — it reads Palette for the notes, colours them through the
## shared NoteColors mapping, and listens to NoteBus for flashes. It never
## affects gameplay, so like the synth and the ring it does not gate on
## effects_enabled(); it just shows what notes exist and which one was struck.

## Slot geometry in internal (320x180) pixels. Tune by feel.
@export var slot_size: Vector2 = Vector2(28.0, 24.0)
@export var slot_gap: float = 4.0
@export var margin_bottom: float = 6.0
## Seconds a slot stays lit after its note is played.
@export var flash_time: float = 0.18

var _flash: Array[float] = []  # remaining flash time per slot, seconds
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _i in Palette.slot_count():
		_flash.append(0.0)
	NoteBus.note_played.connect(_on_note_played)


func _on_note_played(midi: int, _source: Vector2) -> void:
	for slot in _flash.size():
		if Palette.midi_for_slot(slot) == midi:
			_flash[slot] = flash_time
	queue_redraw()


func _process(delta: float) -> void:
	var lit := false
	for slot in _flash.size():
		if _flash[slot] > 0.0:
			_flash[slot] = maxf(_flash[slot] - delta, 0.0)
			lit = true
	if lit:
		queue_redraw()


func _draw() -> void:
	var count := Palette.slot_count()
	if count == 0:
		return
	var total_w := count * slot_size.x + (count - 1) * slot_gap
	var start_x := (size.x - total_w) * 0.5
	var y := size.y - slot_size.y - margin_bottom
	for slot in count:
		var x := start_x + slot * (slot_size.x + slot_gap)
		_draw_slot(Rect2(x, y, slot_size.x, slot_size.y), slot)


func _draw_slot(rect: Rect2, slot: int) -> void:
	var midi := Palette.midi_for_slot(slot)
	var base := NoteColors.color_for_midi(midi) if midi >= 0 else Color(0.2, 0.2, 0.24)

	# Colour first: the swatch is the primary channel. Flash brightens it toward
	# white on press, fading back over flash_time.
	var flash_t := (_flash[slot] / flash_time) if flash_time > 0.0 else 0.0
	draw_rect(rect, base.lerp(Color.WHITE, flash_t * 0.8), true)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)

	# Note name second: small, centred near the swatch's lower edge.
	if midi >= 0 and _font != null:
		var baseline := Vector2(rect.position.x, rect.end.y - 4.0)
		draw_string(
			_font, baseline, NoteNames.to_name(midi),
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color(0.0, 0.0, 0.0, 0.85)
		)
