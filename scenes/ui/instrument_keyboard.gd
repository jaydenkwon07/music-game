class_name InstrumentKeyboard
extends Control
## The instrument-state keyboard widget (M3 addendum). While the instrument state
## is active it shows ONE OCTAVE of the home-row piano (§6): seven white slots
## (A S D F G H J) and five black slots (W E / T Y U) with the real gaps at E-F
## and B-C, so the shape maps one-to-one onto the keys under the player's hand.
## Answering "which key plays the note I want" is the whole point — a list of
## "A = your note" would teach nothing transferable.
##
## The twelve slots are exactly the twelve collectible pitch classes (§6). An
## owned slot is filled with the note's colour (NoteRegistry -> NoteColors —
## colour is the primary channel, §6) and labelled with its physical key letter;
## an unowned slot is an empty outline. Early game it is mostly empty and fills in
## as the player collects, and that progression is intentional.
##
## Presentational only (§ addendum): it reads NoteInventory / InputConfig /
## NoteRegistry, and decides nothing. No pitch name and no key letter is
## hardcoded — semitone->key comes from InputConfig's data-driven map, and the
## letter from DisplayServer.keyboard_get_label_from_physical(), so it stays
## correct on AZERTY/Dvorak (§5).

## White-key size in internal (640x360) pixels, and the gap between whites (all
## doubled from M3 in the §4 resolution migration). Small by design: seven whites
## at ~20px is ~140px across — it must not dominate a frame already crowded by the
## note bar (§ addendum size budget). Tune by feel.
@export var white_size: Vector2 = Vector2(20.0, 48.0)
@export var white_gap: float = 2.0
@export var black_height: float = 28.0
## Distance from the bottom of the frame to the bottom of the white row. Clears
## the note bar (~60px tall at the bottom) so the two don't overlap.
@export var margin_bottom: float = 68.0
## Seconds a slot stays lit after its note is struck (Step 2). Matches the note
## bar so a played note flashes both in step.
@export var flash_time: float = 0.18
## Melody-strip geometry (Step 3): marker radius, gap between markers, and how far
## the strip sits above the keyboard's top edge. Matches the door gems' size so
## the door and the strip read as the same language.
@export var marker_radius: float = 5.0
@export var marker_gap: float = 4.0
@export var strip_margin: float = 18.0
## Seconds the whole widget fades in/out with the scrim (§9), so the panel eases in
## rather than popping. Matches InstrumentOverlay.fade_time by default.
@export var panel_fade_time: float = 0.18

var _fade_tween: Tween
var _font: Font
var _slots: Array = []            # cached InstrumentKeyboardLayout.slots(), local origin
var _flash: Array[float] = []     # remaining flash seconds, indexed by semitone 0..11
var _octave_shift: int = 0        # cached from InputConfig, updated on octave_changed
var _melody_targets: Array = []   # armed door's target MIDI, for the melody strip (Step 3)
var _melody_progress: int = 0     # confirmed notes so far, mirrored from the lock


func _ready() -> void:
	# The project's bitmap font (M4 §7), not the antialiasing engine fallback.
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slots = InstrumentKeyboardLayout.slots(
		white_size.x, white_gap, white_size.y, black_height
	)
	_flash.resize(12)
	_flash.fill(0.0)
	_octave_shift = InputConfig.octave_shift()
	# Only visible in the instrument state — the piano bindings are live only then.
	visible = NoteBus.instrument_state_active
	modulate.a = 1.0 if visible else 0.0
	NoteBus.instrument_state_changed.connect(_on_instrument_state_changed)
	# Fills in a slot as the player collects (§ addendum Step 1).
	NoteInventory.note_collected.connect(_on_note_collected)
	# Step 2 live feedback: a struck key flashes; the octave indicator tracks [ ].
	NoteBus.note_played.connect(_on_note_played)
	InputConfig.octave_changed.connect(_on_octave_changed)
	# Step 3 melody strip: mirror the armed door's structure and progress.
	NoteBus.melody_armed.connect(_on_melody_armed)
	NoteBus.melody_progress.connect(_on_melody_progress)
	set_process(false)  # only runs while a flash is decaying


func _on_instrument_state_changed(active: bool) -> void:
	if active:
		# reset_octave() already fired on entry; sync in case we missed the signal.
		_octave_shift = InputConfig.octave_shift()
		visible = true
		_fade_to(1.0)
	else:
		# No stale flash or strip lingers into the next visit — the next door
		# re-arms and re-sends its own structure.
		_flash.fill(0.0)
		_melody_targets = []
		_melody_progress = 0
		set_process(false)
		# Ease out with the scrim, then hide once invisible.
		_fade_to(0.0)
	queue_redraw()


## Fade the whole widget toward `target` alpha over panel_fade_time (§9); hide it
## when it reaches zero so it stops drawing. Replaces any in-flight fade.
func _fade_to(target: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if panel_fade_time <= 0.0:
		modulate.a = target
		visible = target > 0.0
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target, panel_fade_time)
	if target <= 0.0:
		_fade_tween.tween_callback(func() -> void: visible = false)


func _on_note_collected(_note_id: String) -> void:
	queue_redraw()


## A note sounded: flash the slot for its pitch class. Octave-independent (like the
## note bar) — the twelve slots are pitch classes, so the octave shift never moves
## which slot lights. Overworld plays are ignored; the widget is hidden then.
func _on_note_played(midi: int, _source: Vector2) -> void:
	if not NoteBus.instrument_state_active:
		return
	_flash[NoteNames.pitch_class(midi)] = flash_time
	set_process(true)
	queue_redraw()


func _on_octave_changed(shift: int) -> void:
	_octave_shift = shift
	queue_redraw()


func _on_melody_armed(targets: Array) -> void:
	_melody_targets = targets
	_melody_progress = 0
	queue_redraw()


func _on_melody_progress(progress: int, _total: int) -> void:
	_melody_progress = progress
	queue_redraw()


func _process(delta: float) -> void:
	var lit := false
	for pc in _flash.size():
		if _flash[pc] > 0.0:
			_flash[pc] = maxf(_flash[pc] - delta, 0.0)
			lit = true
	if lit:
		queue_redraw()
	else:
		set_process(false)


func _draw() -> void:
	# Bottom-centred, above the note bar. Whites first, then blacks over them.
	var row_w := InstrumentKeyboardLayout.row_width(white_size.x, white_gap)
	var origin := Vector2(
		(size.x - row_w) * 0.5,
		size.y - margin_bottom - white_size.y
	)
	for slot in _slots:
		if slot["white"]:
			_draw_slot(slot, origin)
	for slot in _slots:
		if not slot["white"]:
			_draw_slot(slot, origin)
	_draw_octave_indicator(origin)
	_draw_melody_strip(origin, row_w)


func _draw_slot(slot: Dictionary, origin: Vector2) -> void:
	var semitone: int = slot["semitone"]
	var rect: Rect2 = (slot["rect"] as Rect2)
	rect.position += origin

	var owned := NoteInventory.owns_pitch_class(semitone)
	if owned:
		# Colour first: the note's category colour at the current octave, brightened
		# toward white for the flash_time after it is struck (Step 2). Only owned
		# keys flash — an unowned key is silent, so it never sounds a note.
		var flash_t := _flash[semitone] / flash_time if flash_time > 0.0 else 0.0
		var fill := _color_for(semitone).lerp(EnvPalette.color("bright"), flash_t * 0.8)
		draw_rect(rect, fill, true)
		draw_rect(rect, EnvPalette.with_alpha("ink", 0.6), false, 1.0)
		_draw_key_letter(rect, semitone)
	else:
		# Empty outline: a faint fill so the piano shape still reads against the
		# scrim, with the slot clearly unfilled.
		var ground := EnvPalette.with_alpha("bright", 0.10) if slot["white"] else EnvPalette.with_alpha("ink", 0.28)
		draw_rect(rect, ground, true)
		draw_rect(rect, EnvPalette.with_alpha("bright", 0.22), false, 1.0)


## The colour for an owned slot: resolve the pitch class to a MIDI at the piano's
## current octave and route through NoteRegistry -> NoteColors (§6). Octave sets
## brightness, so shifting octaves later dims/brightens the whole widget for free.
func _color_for(semitone: int) -> Color:
	var base_c := (InputConfig.piano_base_octave() + _octave_shift + 1) * 12
	return NoteRegistry.color_for_midi(base_c + semitone)


## A small octave indicator at the keyboard's top-left edge (Step 2): the octave
## the widget currently represents, base_octave shifted by `[` / `]`. It resets to
## the base on entry (InputConfig.reset_octave), and brightens when shifted off
## home so leaving the base octave is legible. Just the number — no pitch letter,
## which would be content (§3).
func _draw_octave_indicator(origin: Vector2) -> void:
	if _font == null:
		return
	var octave := InputConfig.piano_base_octave() + _octave_shift
	var shifted := _octave_shift != 0
	var ink := EnvPalette.with_alpha("bright", 0.95) if shifted else EnvPalette.with_alpha("rock_high", 0.7)
	var baseline := Vector2(origin.x, origin.y - 6.0)
	draw_string(
		_font, baseline, "oct %d" % octave, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink
	)


## The armed door's melody strip (Step 3): one marker per target note, centred in
## a row directly above the keyboard, category-tinted and lit left-to-right by the
## lock's progress — so the target the door wants sits right beside the instrument
## that plays it. STRUCTURE ONLY (§6): count, categories, progress. Each marker
## uses its category's representative index, never the note's real index, so it
## reveals the family (warm / green / cool) but never which of the four notes it
## is — identical to the door gems (D-M3-3). Empty when no lock is armed.
func _draw_melody_strip(origin: Vector2, row_w: float) -> void:
	var count := _melody_targets.size()
	if count <= 0:
		return
	var spacing := marker_radius * 2.0 + marker_gap
	var strip_w := count * spacing - marker_gap
	var start_x := origin.x + (row_w - strip_w) * 0.5 + marker_radius
	var y := origin.y - strip_margin
	for i in count:
		var base := _category_color(int(_melody_targets[i]))
		# Lit if confirmed, dim otherwise — the target colour still reads when dim.
		var col := base if i < _melody_progress else base.darkened(0.6)
		var pos := Vector2(start_x + i * spacing, y)
		draw_circle(pos, marker_radius, col)
		draw_arc(pos, marker_radius, 0.0, TAU, 16, EnvPalette.with_alpha("ink", 0.5), 1.0)


## A target note's CATEGORY colour, at the category's representative index — the
## same mapping the door gem uses (Door.CATEGORY_REP_INDEX), so the strip and the
## door speak one colour language. An unassigned pitch class falls back to NEUTRAL.
func _category_color(midi: int) -> Color:
	var note := NoteRegistry.by_midi(midi)
	if note.is_empty():
		return NoteColors.NEUTRAL
	var octave := int(floor(float(midi) / 12.0)) - 1
	return NoteColors.color(note["category"], Door.CATEGORY_REP_INDEX, octave)


## Draw the slot's physical key letter, read from the registered piano action —
## never a hardcoded string (§5). Dark on a light (white-key) fill, light on a
## dark (black-key) fill.
func _draw_key_letter(rect: Rect2, semitone: int) -> void:
	if _font == null:
		return
	var label := _key_label(semitone)
	if label.is_empty():
		return
	var ink := EnvPalette.with_alpha("ink", 0.85) if _is_white(semitone) else EnvPalette.with_alpha("bright", 0.9)
	var baseline := Vector2(rect.position.x, rect.end.y - 6.0)
	draw_string(
		_font, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, ink
	)


func _is_white(semitone: int) -> bool:
	return InstrumentKeyboardLayout.WHITE_SEMITONES.has(semitone)


## The layout-dependent letter for the key bound to `semitone`, via the physical
## keycode registered for that piano action (§3: the semitone->key map is data in
## InputConfig, not a literal here). Empty if the semitone is unbound.
func _key_label(semitone: int) -> String:
	for action in InputConfig.piano_actions():
		if InputConfig.piano_semitone(action) != semitone:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var physical: Key = (event as InputEventKey).physical_keycode
				var label := DisplayServer.keyboard_get_label_from_physical(physical)
				return OS.get_keycode_string(label)
	return ""
