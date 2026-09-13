# Music Game — M1, the note toy

Godot 4.7 project. Top-down, 320×180 internal resolution, integer-scaled.

Design doc lives separately (`music-game-design-doc.md` / Google Drive → Game Design Logs).
Milestone record: `docs/m1-progress.md`.

## State

**M0 and M1 built and verified.** M0 is movement + the data seam; M1 is the note
toy — playing notes that make sound and visible effects. M1's *build* is
complete; its aesthetic gate ("does playing feel good on its own") is **deferred
until the placeholder sine is replaced with real composed sound** — see
`docs/m1-progress.md`. Next is M2 (one data-driven door).

## Running it

1. Godot 4.7 → Import → select this folder's `project.godot`.
2. Let it re-save the project on first open.
3. Run the project (or `godot .` from a terminal to see `print()` output).

Expected: a gray room, a white square you move in eight directions (WASD or
arrows, Tab swaps). Press **1–5** to play the five palette notes — each sounds a
tone, drops an expanding colour ring, and flashes its slot in the note bar along
the bottom. Three dim "resonator" blocks sit above the spawn; walk up to one and
play its note to light it, or a wrong note to make it shake. A debug line at the
top shows viewport size, layout and speed.

Tests:

```
godot --headless --script tests/test_melody_matcher.gd
```

29 assertions, no engine state required. Exit code is non-zero on failure, so
this drops straight into CI.

## Layout

```
autoload/
  input_config.gd     InputMap built in code — two default layouts, rebindable
  note_bus.gd         global signal bus for played notes
  melody_library.gd   loads data/melodies/*.json at boot
  palette.gd          loads the active note palette; slot -> pitch
  synth.gd            runtime AudioStreamGenerator synth, polyphonic
  note_visuals.gd     spawns a colour ring per played note
scripts/music/
  note_names.gd       pitch name <-> MIDI <-> frequency, pure
  melody_matcher.gd   does this attempt satisfy this melody? pure
  note_colors.gd      pitch -> colour (pitch class = hue, octave = brightness), pure
scenes/
  main.tscn/.gd       entry point; spawns test resonators
  player/             8-direction movement + note input
  rooms/test_room.*   gray box, built in code, deleted at M3
  fx/note_ring.gd     expanding, fading ring
  ui/note_bar.gd      five-slot note bar
  objects/resonator.gd  block tuned to a palette slot, responds to its note
data/
  melodies/door_test_01.json   the melody schema, as a working example
  palettes/starter.json        the overworld note palette
tests/
  test_melody_matcher.gd
```

## The one rule

**No pitch, melody or musical pattern ever appears in a `.gd` file.** Code refers
to melodies by id and notes by palette slot; the pitches live in `data/`. If
you're typing a note name into a script, stop.

To prove it still holds:

```
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'
```

Should return nothing. Two files are exempt: `tests/` needs literal notes to
assert against, and `note_names.gd` mentions them in doc comments because
converting them is its entire job. Anywhere else is a violation.

## What isn't in yet

No doors, note collection, melody locks, note categories (every note gets the
same generic effect in M1), combat, art, story, menus, saves, or the instrument
state (the bus supports it; nothing enters it yet). Those belong to M2 and later.

## Numbers worth arguing with

- `Synth.master_gain` / `voice_gain` / `decay_tau` / `attack` — the feel and
  level of the placeholder sound. The sound gets replaced with real composition.
- `NoteColors` consts — `HUE_OFFSET` rotates the whole colour language.
- `Player.max_speed` — 80 px/s. `acceleration_time` — 0.05s. Movement tuning is
  deliberately deferred (§7 non-goals) until there's a reason to move.
- `TestRoom.room_tiles` — 30×18 tiles at 16px, larger than one screen.
