# Resonance

Godot 4.7 project. A 2D top-down game where the player collects musical notes and
plays melodies to open doors. **960×540 internal resolution**, integer-scaled
(fixed pixel-art SubViewport upscaled ×2→1080p / ×4→4K, letterboxed). Pixel art,
keyboard only, PC.

Design doc lives separately (`music-game-design-doc.md` / Google Drive → Game
Design Logs). The working agreement is `CLAUDE.md`; per-milestone records are in
`docs/`.

## State

**M0–M6 built.** M0 movement + data seam; M1 the note toy; M2 one data-driven
door; M3 the vertical slice (four rooms, real transitions, persistent doors,
clue chimes, room-clamped camera, instrument-state keyboard widget); M4 the
technical visual foundation; M5 the cave look; **M6 the authoring pipeline +
room two.**

**M5 is complete (2026-09-20) — the store-page gate is MET.** The **Cistern**
(`room_a`, 48×36, the first scrolling room) is composed to store-page quality: a
procedural rock tileset on a 47-tile blob terrain with bevelled corners, banded
light + a vignette, doors as designed art objects (carved stone + brass organ
pipes + category gems, the brightest beacons; an opened door stays a lit
landmark), a decorative five-socket sealed door, and a light rubble detail pass.
The reference still is `docs/m5-reference/cistern-final.png`. Record:
`docs/m5-progress.md`.

**M6 is complete (2026-09-21) — gate MET.** The **Gallery** (`room_b`, 96×18, a
3-screen horizontal shelf) is authored to the M5 bar and its geometry is LOCKED;
the authoring pipeline that made it cheaper is the `room.gd` split
(`RoomGeometry` + `RoomContent`) and the room lint (`lint_rooms.py` on
`roomlib.py`). The Gallery is a deliberately dim traversal shelf (doorless, so no
light beacon). Recipe: `docs/room-authoring.md`; record: `docs/m6-progress.md`;
reference still: `docs/m6-reference/gallery-final.png`.

Open gates carried forward: **M3's play-through gate** (a stranger gets the loop
in 5–10 min) is **waived** to M7's stronger version (2026-09-18); **M1's aesthetic
gate** ("does playing feel good on its own") stays deferred until the placeholder
sine is replaced with real composed sound.

**M7 — the grey-box map — is underway.** Its **code spine is built and merged**
(2026-09-22): the ability-gate schema, `scripts/new_room.py`, and the real
eleven-room `data/rooms.json` with nine walkable grey-box rooms (open boxes;
archetype shaping deferred), Doors A/B/C/Ω, and Ω's three fragment chimes — the
map is connected, gated, solvable and runs. Spec + plan under
`docs/superpowers/`. **Remaining (the carving phase):** carve the rooms to their
archetypes, the Cistern's fifth opening + one-way shortcut, then the **stranger
play-through gate — carries M3's waived gate and must not be waived.**

## Running it

1. Godot 4.7 → Import → select this folder's `project.godot`.
2. Let it re-save the project on first open.
3. Run the project (or `godot .` from a terminal to see `print()` output).

You start in a dark, dynamically-lit cave (the Cistern) with **nothing** — an
empty note bar. Move a small figure in eight directions (**WASD** or **arrows**;
**Tab** swaps the movement layout *and* the palette together). Your light grows
as you collect notes.

- **Collect notes.** Walk onto a floating diamond pickup and press **space** — the
  note bar gains a swatch coloured by the note's category, and the pickup's light
  folds into yours. **Space is the single world verb.**
- **Play in the overworld.** The palette sits under the resting hand:
  **H J K L ;** in WASD mode, **A S D F G** in arrows mode. Each plays its note —
  a tone, an expanding colour ring, a spark, a flash in the note bar.
- **Read a clue.** A struck **chime** (a hanging vertical bar, not a pickup) plays
  a door's melody, pulsing each note's colour in order.
- **Open a door.** Press **space** at a door to enter the instrument state:
  movement suspends, a scrim and the home-row piano widget ease in over the
  still-running world. Play **A S D F G H J K L ;** (white) and **W E T Y U O P**
  (black), `R`/`I` unbound where a piano has no black key. Only **owned** pitch
  classes sound; **[** / **]** shift octave. Play the door's melody and it unlocks
  with a choreographed payoff (gems flaring, a shake, dust, the melody resolving);
  a wrong note resets the gems with no penalty. **Space**/**Esc** exits instantly.

## Tests

```
godot --headless --script tests/test_melody_matcher.gd            # 32 assertions
godot --headless --script tests/test_instrument_keyboard_layout.gd # 21 assertions
python3 scripts/validate_rooms.py                                 # reachability/solvability/ramp
```

The `.gd` suites need no engine state and exit non-zero on failure (CI-ready). The
room validator is pure Python over the geometry data and never boots the engine.

## The one rule

**No pitch, melody or musical pattern ever appears in a `.gd` file.** Code refers
to melodies by id and to notes by id or palette slot; the pitches, the
keyboard→pitch map and the note categories all live in `data/`. `EnvPalette`
extends the same rule to environment colour — no hex literal in a scene or script.

To prove it still holds:

```
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'
```

Should return nothing. `tests/` and `note_names.gd` are the only exempt files.

## Layout

```
autoload/
  input_config.gd     InputMap in code — movement, palette (mirrored to the hand),
                      home-row piano, interact/octave; two layouts, rebindable
  note_bus.gd         global signal bus: note_played, instrument_state, melody_armed/
                      progress, shake_requested
  melody_library.gd   loads data/melodies/*.json at boot, lookup by id
  note_registry.gd    loads data/notes.json; id/midi -> {category, index}
  note_inventory.gd   what the player owns (pitch classes) + equipped slots
  synth.gd            runtime AudioStreamGenerator synth, polyphonic (placeholder sine)
  note_visuals.gd     spawns a colour ring per played note
  room_graph.gd       loads data/rooms.json + per-room geometry; boot consistency check
  world_state.gd      opened doors + taken pickups; survives room re-instancing
  env_palette.gd      locked environment colours from data/palette.json (the one rule, colour)
scripts/music/        (pure: no nodes, no signals, unit-tested)
  note_names.gd       pitch name <-> MIDI <-> frequency
  melody_matcher.gd   does this attempt satisfy this melody?
  note_colors.gd      (category, index, octave) -> colour
scenes/
  main.tscn/.gd       render root: 960×540 SubViewport upscaled by a Display TextureRect
  world.tscn/.gd      persistent gameplay host inside the viewport; room swap + camera clamp
  player/             8-direction movement, note input, the interact verb, growing light
  rooms/room.gd       builds a room from data; rock_tileset.gd is the placeholder tileset
  fx/                 note_ring, lighting (additive PointLight2D factory),
                      particle_burst, collect_flash
  ui/                 note_bar, instrument_overlay, instrument_keyboard (+ melody strip)
  objects/            interactable (the world-verb seam), resonator, note_pickup,
                      melody_chime, melody_lock, door (+ door_gems)
data/
  notes.json          the note registry (category/colour source of truth)
  palette.json        the locked environment palette
  keyboard_layout.json  piano semitone map + per-layout palette keys
  rooms.json + rooms/*.json   the room graph and per-room geometry (tile coordinates)
  melodies/*.json     per-door melodies
tests/                melody-matcher + keyboard-geometry suites
scripts/              validate_rooms.py (+ one-off migration helpers)
```

## What isn't in yet

The **final quality of the other nine rooms** (Cistern + Gallery are composed to
the M5 bar; M7's other nine exist as walkable grey-box open boxes, not yet carved
to their archetypes or lit), note **behaviours** (categories are data only; nothing acts on them),
combat, story, menus, saves, a melody journal, rhythm/timing matching, real
**audio** (the synth is a placeholder sine), and **bloom** (the pipeline hosts it;
the vignette ships, bloom stays off).

## Numbers worth arguing with

Most feel values are `@export`ed for tuning in the inspector or by editing the
script default:

- `Synth.master_gain` / `voice_gain` / `decay_tau` / `attack` — the placeholder
  sound; replaced with real composition later.
- `NoteColors.CATEGORY_ARC` — the hue arc each category owns.
- `Player.max_speed` (240 px/s at 960×540), `acceleration_time`,
  `camera_follow_speed` — movement and camera feel.
- `Door.unlock_*` — the unlock choreography (held beat, gem flare, shake, dust).
- Object/UI sizes (`Door.slab_size`, `DoorGems.gem_radius`, `NoteBar.slot_size`,
  `InstrumentKeyboard.white_size`, the fx radii) — all in 960×540 pixels.
- Room tiles are 30px; a 32×18 room is exactly one 960×540 screen.
```
