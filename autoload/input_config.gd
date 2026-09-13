extends Node
## Builds the InputMap at runtime instead of baking it into project.godot.
##
## Two reasons this lives in code rather than the editor's Input Map panel:
##   1. Rebinding is a day-one requirement (see design doc 12.1), and a
##      dictionary is far easier to rebind and serialise than editor state.
##   2. Two movement layouts ship as defaults. Swapping them is one call.
##
## M2 adds two data-driven action groups loaded from data/keyboard_layout.json:
## the overworld PALETTE (mirrored to the free hand, per movement layout) and the
## instrument-state PIANO (a home-row layout of semitone offsets). Keeping the
## semitone map here means one loader owns both the binding and the offset lookup,
## and no pitch literal enters code (§3 corollary).

enum Layout { WASD, ARROWS }

const MOVEMENT := {
	Layout.WASD: {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
	},
	Layout.ARROWS: {
		"move_up": KEY_UP,
		"move_down": KEY_DOWN,
		"move_left": KEY_LEFT,
		"move_right": KEY_RIGHT,
	},
}

## System actions, same in both layouts. `interact` (space) enters/exits the
## instrument state; `cancel` (escape) is layered — it exits the instrument state
## when active and is otherwise reserved for pause. Octave shift is `[` / `]`
## (§4.2, D4/D5). Space is the one key either hand reaches without leaving its
## movement keys.
const SYSTEM := {
	"interact": [KEY_SPACE],
	"cancel": [KEY_ESCAPE],
	"octave_down": [KEY_BRACKETLEFT],
	"octave_up": [KEY_BRACKETRIGHT],
}

## Overworld palette action names are PALETTE_ACTION_PREFIX + slot index. The keys
## they bind to are DATA (keyboard_layout.json), mirrored to the movement layout.
const PALETTE_ACTION_PREFIX := "note_slot_"
const KEYBOARD_LAYOUT_PATH := "res://data/keyboard_layout.json"
## Octave shift clamps to ±this so a door attempt can't wander far, and resets to
## 0 on entering the instrument state (§4.2).
const OCTAVE_SHIFT_LIMIT := 2

var current_layout: Layout = Layout.WASD

# Loaded from data/keyboard_layout.json.
var _piano_base_octave: int = 4
var _piano_key_defs: Array = []               # [{action, physical_key, semitone}], in order
var _piano_actions: Array[String] = []        # registered piano action names, in order
var _piano_semitone: Dictionary = {}          # action -> semitone offset
var _palette_layout_keys: Dictionary = {}     # "wasd"/"arrows" -> [key-name strings]
var _palette_actions: Array[String] = []      # active layout's slot actions, slot order

## Current octave shift for the instrument-state piano, clamped ±OCTAVE_SHIFT_LIMIT.
var _octave_shift: int = 0


func _ready() -> void:
	_load_keyboard_layout()
	apply_layout(current_layout)
	_register_system()
	_register_piano()


## Clears and re-registers the movement AND overworld-palette actions for a
## layout. They are one choice, not two: the palette mirrors the movement hand
## (§6), so the Tab debug swap must move both together.
func apply_layout(layout: Layout) -> void:
	current_layout = layout
	for action in MOVEMENT[layout]:
		_reset_action(action)
		_add_key(action, MOVEMENT[layout][action])
	_register_palette(layout)


## Rebind a single action to a single physical key. Returns false if the key is
## already claimed by another action IN THE SAME GROUP. The groups (movement /
## palette / piano / system) deliberately share physical keys — palette H J K L ;
## are also piano white keys, movement W A S D are also piano keys — because they
## are read in mutually exclusive modes (§4.2). A global guard would reject those
## valid bindings and report phantom conflicts (D7).
func rebind(action: StringName, keycode: Key) -> bool:
	var group := _group_of(action)
	if _key_owner(keycode, group) not in [action, &""]:
		return false
	_reset_action(action)
	_add_key(action, keycode)
	return true


# --- Piano / palette accessors (the contract with note_input, §5.5) ---

## Registered piano action names, in ascending semitone order.
func piano_actions() -> Array[String]:
	return _piano_actions


## Semitone offset for a piano action from base_octave's C, or -1 if unknown.
func piano_semitone(action: String) -> int:
	return _piano_semitone.get(action, -1)


## The octave whose C is offset 0 on the piano layout.
func piano_base_octave() -> int:
	return _piano_base_octave


## Overworld slot actions for the active movement layout, in slot order.
func palette_actions() -> Array[String]:
	return _palette_actions


## Current instrument-state octave shift, clamped ±OCTAVE_SHIFT_LIMIT.
func octave_shift() -> int:
	return _octave_shift


## Shift the piano octave, clamped. octave_matters is false in M2 so this changes
## nothing mechanically — it just stops one fixed octave feeling like a cage.
func shift_octave(delta: int) -> void:
	_octave_shift = clampi(_octave_shift + delta, -OCTAVE_SHIFT_LIMIT, OCTAVE_SHIFT_LIMIT)


## Reset to the base octave — called when entering the instrument state so a door
## attempt always starts from a known place (§4.2).
func reset_octave() -> void:
	_octave_shift = 0


# --- Loading & registration ---

func _load_keyboard_layout() -> void:
	var file := FileAccess.open(KEYBOARD_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_warning("InputConfig: could not open %s." % KEYBOARD_LAYOUT_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("InputConfig: %s is not a JSON object." % KEYBOARD_LAYOUT_PATH)
		return

	var piano: Dictionary = parsed.get("piano", {})
	_piano_base_octave = int(piano.get("base_octave", 4))
	_piano_key_defs = piano.get("keys", [])

	var palette: Dictionary = parsed.get("palette", {})
	_palette_layout_keys = {
		"wasd": palette.get("wasd", []),
		"arrows": palette.get("arrows", []),
	}
	# Honour the data's default movement/palette layout.
	current_layout = _layout_from_string(str(palette.get("default_layout", "wasd")))


func _register_system() -> void:
	for action in SYSTEM:
		_reset_action(action)
		for keycode in SYSTEM[action]:
			_add_key(action, keycode)


## Registers the overworld palette for a layout, mirrored to the free hand. Rebuilt
## on every layout swap so movement and palette stay in step.
func _register_palette(layout: Layout) -> void:
	_palette_actions.clear()
	var keys: Array = _palette_layout_keys.get(_layout_to_string(layout), [])
	for i in keys.size():
		var action := PALETTE_ACTION_PREFIX + str(i)
		var keycode := _key_from_name(str(keys[i]))
		_reset_action(action)
		if keycode != KEY_NONE:
			_add_key(action, keycode)
		_palette_actions.append(action)


## Registers the instrument-state piano from data: one action per key, its
## semitone offset stored for the pitch lookup. Bound once — the piano keys are
## the same in both movement layouts (movement is suspended here, so there is no
## collision to design around, §6).
func _register_piano() -> void:
	_piano_actions.clear()
	_piano_semitone.clear()
	for entry in _piano_key_defs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action := str(entry.get("action", ""))
		if action.is_empty():
			continue
		var keycode := _key_from_name(str(entry.get("physical_key", "")))
		_reset_action(action)
		if keycode != KEY_NONE:
			_add_key(action, keycode)
		_piano_semitone[action] = int(entry.get("semitone", 0))
		_piano_actions.append(action)


func _reset_action(action: StringName) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)


func _add_key(action: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	# physical_keycode so the bindings follow key position, not layout.
	# Matters for AZERTY/Dvorak players on a WASD default.
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


## Resolve a data key-name ("A", "SEMICOLON", "BRACKETLEFT") to a physical Key.
## Case-insensitive; KEY_NONE for an unrecognised name (a bad data file surfaces
## as a dead key, not a crash at boot).
func _key_from_name(name: String) -> Key:
	if name.is_empty():
		return KEY_NONE
	return OS.find_keycode_from_string(name) as Key


## Which action group an action belongs to, for the per-group rebind guard.
func _group_of(action: StringName) -> String:
	var s := str(action)
	if s.begins_with("move_"):
		return "movement"
	if s.begins_with(PALETTE_ACTION_PREFIX):
		return "palette"
	if s.begins_with("piano_"):
		return "piano"
	return "system"


## The action in `group` that owns `keycode`, or &"" if none — so duplicate keys
## across groups don't read as conflicts (§4.2, D7).
func _key_owner(keycode: Key, group: String) -> StringName:
	for action in InputMap.get_actions():
		if _group_of(action) != group:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keycode:
				return action
	return &""


func _layout_from_string(name: String) -> Layout:
	return Layout.ARROWS if name.to_lower() == "arrows" else Layout.WASD


func _layout_to_string(layout: Layout) -> String:
	return "arrows" if layout == Layout.ARROWS else "wasd"
