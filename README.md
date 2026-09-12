# Music Game — M0 scaffold

Godot 4 project. Top-down, 320×180 internal resolution, integer-scaled.

Design doc lives separately (`music-game-design-doc.md` / Google Drive → Game Design Logs).

## Running it

1. Godot 4.3 or newer → Import → select this folder's `project.godot`.
2. Godot will ask to re-save the project on first open. Let it.
3. F5.

Expected: a gray room, a white square you can move in eight directions, a
debug line at the top showing viewport size, active layout and current speed.
Tab swaps between WASD and arrow keys. The console prints a seam check and a
placeholder count.

Tests:

```
godot --headless --script tests/test_melody_matcher.gd
```

20 assertions, no engine state required. Exit code is non-zero on failure, so
this drops straight into CI.

## Layout

```
autoload/
  input_config.gd     InputMap built in code — two default layouts, rebindable
  note_bus.gd         global signal bus for played notes
  melody_library.gd   loads data/melodies/*.json at boot
scripts/music/
  note_names.gd       pitch name <-> MIDI, pure
  melody_matcher.gd   does this attempt satisfy this melody? pure
scenes/
  main.tscn           entry point
  player/             8-direction movement
  rooms/test_room.*   gray box, built in code, deleted at M3
data/melodies/
  door_test_01.json   the schema, as a working example
tests/
  test_melody_matcher.gd
```

## The one rule

**No pitch, melody or musical pattern ever appears in a `.gd` file.** Code
refers to melodies by id; the notes live in `data/melodies/`. If you're typing
a note name into a script, stop.

To prove it still holds:

```
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'
```

Should return nothing. Two files are exempt: `tests/` needs literal notes to
assert against, and `note_names.gd` mentions them in doc comments because
converting them is its entire job. Anywhere else is a violation.

## What M0 deliberately does not have

No notes, no sound, no doors, no collection, no art, no menus, no saves, no
enemies. Movement and the data seam only. The seam is here early because it's
the one thing that's painful to retrofit; everything else waits.

## Next: M1, the note toy

Give the player a way to play notes and make each one do something visible.
No goals, no doors. **The gate: sitting in a gray room playing notes should
feel good on its own.** If it doesn't, the design needs rethinking, and better
to find that out now than after a year of level building.

Wiring already in place for it: `note_slot_0`–`note_slot_4` actions on the
number row, and `NoteBus.play_note(midi, position)`.

## Numbers worth arguing with

- `Player.max_speed` — 60 px/s. The most important number in the project today.
- `Player.acceleration_time` — 0.05s. Zero for Undertale-crisp, higher for weight.
- `TestRoom.room_tiles` — 30×18 tiles at 16px, so the room is larger than one screen.
