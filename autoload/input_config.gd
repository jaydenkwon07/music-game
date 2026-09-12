extends Node
## Builds the InputMap at runtime instead of baking it into project.godot.
##
## Two reasons this lives in code rather than the editor's Input Map panel:
##   1. Rebinding is a day-one requirement (see design doc 12.1), and a
##      dictionary is far easier to rebind and serialise than editor state.
##   2. Two movement layouts ship as defaults. Swapping them is one call.

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

## Non-movement actions. Same in both layouts.
const COMMON := {
	"interact": [KEY_E, KEY_ENTER],
	"cancel": [KEY_ESCAPE],
}

## Overworld ability-note palette. Number row: ordered left-to-right,
## reachable from either movement layout. M1 wires these up; M0 only
## registers them so the action names exist.
const PALETTE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const PALETTE_ACTION_PREFIX := "note_slot_"

var current_layout: Layout = Layout.WASD


func _ready() -> void:
	apply_layout(current_layout)
	_register_common()
	_register_palette()


## Clears and re-registers the four movement actions for the given layout.
func apply_layout(layout: Layout) -> void:
	current_layout = layout
	for action in MOVEMENT[layout]:
		_reset_action(action)
		_add_key(action, MOVEMENT[layout][action])


## Rebind a single action to a single physical key. Returns false if the key
## is already claimed by another action, so callers can warn the player.
func rebind(action: StringName, keycode: Key) -> bool:
	if _key_owner(keycode) not in [action, &""]:
		return false
	_reset_action(action)
	_add_key(action, keycode)
	return true


func _register_common() -> void:
	for action in COMMON:
		_reset_action(action)
		for keycode in COMMON[action]:
			_add_key(action, keycode)


func _register_palette() -> void:
	for i in PALETTE_KEYS.size():
		var action := PALETTE_ACTION_PREFIX + str(i)
		_reset_action(action)
		_add_key(action, PALETTE_KEYS[i])


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


func _key_owner(keycode: Key) -> StringName:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keycode:
				return action
	return &""
