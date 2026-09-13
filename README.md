# Music Game — M2, one data-driven door

Godot 4.7 project. Top-down, 320×180 internal resolution, integer-scaled.

Design doc lives separately (`music-game-design-doc.md` / Google Drive → Game Design Logs).
Milestone record: `docs/m2-progress.md` (spec: `docs/m2-spec.md`).

## State

**M0, M1 and M2 built and verified.** M0 is movement + the data seam; M1 is the
note toy (playing notes that sound and make visible effects); **M2 is one
data-driven door** — the player starts empty, collects notes, and a door opens
when the right melody is played on it in an Ocarina-style instrument state.

The M2 gate is met: **change a door's melody JSON and it wants a different tune
with a different number of gems, no code touched.** M1's aesthetic gate ("does
playing feel good on its own") is still **deferred until the placeholder sine is
replaced with real composed sound.** Next is M3, the vertical slice.

## Running it

1. Godot 4.7 → Import → select this folder's `project.godot`.
2. Let it re-save the project on first open.
3. Run the project (or `godot .` from a terminal to see `print()` output).

You start in a gray room with **nothing** — an empty note bar. Move a white
square in eight directions (**WASD** or **arrows**; **Tab** swaps the movement
layout *and* the palette together).

- **Collect notes.** Walk onto one of the three notes on the floor and press
  **space** to pick it up — the note bar gains a swatch, coloured by the note's
  category (C/D/E, one per category). **Space is the single world verb** (it will
  also cover NPCs, hints and further doors later).
- **Play in the overworld.** The palette sits under the resting hand: **H J K L ;**
  in WASD mode, **A S D F G** in arrows mode. Each plays its note — a tone, an
  expanding colour ring, a flash in the note bar. The dim "resonator" blocks light
  when struck with the note they're tuned to.
- **Open a door.** Walk to a door and press **space** to enter the instrument
  state: movement suspends and a scrim fades over the still-running world. Play on
  the home-row piano — **A S D F G H J K L ;** (white: C D E F G A B C D E) and
  **W E T Y U O P** (black), with `R`/`I` unbound where a piano has no black key.
  Only **owned** pitch classes sound; **[** / **]** shift octave. Play the door's
  melody and it opens for good; a wrong note resets the gems with no penalty.
  **Space** or **Esc** leaves the instrument state instantly.

The two doors are the 1-note `door_test_01` (top-left) and the 3-note ordered
`door_test_02` (top-right); their gems show how many notes and their colours.

Tests:

```
godot --headless --script tests/test_melody_matcher.gd
```

32 assertions, no engine state required. Exit code is non-zero on failure, so
this drops straight into CI.

## Layout

```
autoload/
  input_config.gd     InputMap in code — movement, palette (mirrored to the hand),
                      home-row piano and interact/octave actions; two layouts, rebindable
  note_bus.gd         global signal bus: note_played + instrument_state_changed
  melody_library.gd   loads data/melodies/*.json at boot, lookup by id
  note_registry.gd    loads data/notes.json; id/midi -> {category, index}; colour resolution
  note_inventory.gd   what the player owns, by pitch class + slots (started empty)
  synth.gd            runtime AudioStreamGenerator synth, polyphonic
  note_visuals.gd     spawns a colour ring per played note
scripts/music/        (pure: no nodes, no signals, unit-tested)
  note_names.gd       pitch name <-> MIDI <-> frequency
  melody_matcher.gd   does this attempt satisfy this melody?
  note_colors.gd      (category, index, octave) -> colour
scenes/
  main.tscn/.gd       entry point; spawns test resonators, pickups and doors
  player/             8-direction movement, note input (two modes), the interact verb
  rooms/test_room.*   gray box, built in code, deleted at M3
  fx/note_ring.gd     expanding, fading ring
  ui/note_bar.gd      the equipped-slot bar (grows as notes are collected)
  ui/instrument_overlay.gd  scrim that fades over the world in the instrument state
  objects/resonator.gd      block tuned to a palette slot; quiet in the instrument state
  objects/interactable.gd   base: Area2D + interact()/can_interact() — the one world-verb seam
  objects/note_pickup.gd    a collectible note (an Interactable)
  objects/melody_lock.gd    played notes -> MelodyMatcher -> unlocked/progress/mismatch
  objects/door.gd           a melody-locked door (Interactable composing a lock); structure gems
data/
  notes.json                the note registry (category/colour source of truth)
  keyboard_layout.json      piano semitone map + per-layout palette keys
  melodies/door_test_01.json  the 1-note first door
  melodies/door_test_02.json  the 3-note ordered door
tests/
  test_melody_matcher.gd
```

## The one rule

**No pitch, melody or musical pattern ever appears in a `.gd` file.** Code refers
to melodies by id and to notes by id or palette slot; the pitches, the
keyboard→pitch map and the note categories all live in `data/`. If you're typing
a note name into a script, stop.

To prove it still holds:

```
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'
```

Should return nothing. Two files are exempt: `tests/` needs literal notes to
assert against, and `note_names.gd` mentions them in doc comments because
converting them is its entire job. Anywhere else is a violation.

## What isn't in yet

Note **behaviours** (categories are data only — nothing acts on them; that's
M5), multiple rooms, backtracking, world clue delivery (chiming crystals, murals
— M3), combat, art, story, menus, saves, a melody journal, and rhythm/timing
matching. A known M3 prerequisite: the camera doesn't clamp to room bounds, so
out-of-bounds void is visible.

## Numbers worth arguing with

- `Synth.master_gain` / `voice_gain` / `decay_tau` / `attack` — the feel and
  level of the placeholder sound. The sound gets replaced with real composition.
- `NoteColors.CATEGORY_ARC` — the hue arc each category owns.
- `Player.max_speed` — 80 px/s. `acceleration_time` — 0.05s. Movement tuning is
  deliberately deferred until there's a reason to move.
- `Door` gem/slab params and `InstrumentOverlay.max_alpha` — the door and
  instrument-state look, all placeholder.
- `TestRoom.room_tiles` — 30×18 tiles at 16px, larger than one screen.
