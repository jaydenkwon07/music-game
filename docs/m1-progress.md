# M1 — The Note Toy: progress

Status as of **2026-09-12**. M1 is the "note toy" milestone (CLAUDE.md §7): the
player can play notes, each makes a sound and a visible effect. The gate is
whether *sitting in a gray room playing notes feels good on its own*, with no
goal attached — this is a question the milestone exists to answer, not a feature
list to complete.

Build plan is four steps, each stopped at for the owner to run:

| Step | What | State |
|---|---|---|
| 1 | Smallest thing that makes sound | **Done, confirmed audible on device** |
| 2 | Make a note visible (expanding ring + shared colour) | **Implemented; import + tests green; awaiting on-screen confirmation** |
| 3 | The note bar | Not started |
| 4 | The resonator | Not started |

Everything below is committed to nothing yet — all changes are **uncommitted on
`main`**.

---

## Environment note

Godot **4.7.2** was located at `~/Downloads/Godot.app`, moved to
`/Applications/Godot.app`, and aliased (`alias godot=".../MacOS/Godot"` in
`~/.zshrc`). The CLAUDE.md commands now work verbatim. The editor had been run
against the project before this session (contrary to the old "never opened"
note, since corrected in CLAUDE.md §2).

---

## Step 1 — audio, palette, input

### What was built

- **`data/palettes/starter.json`** — the overworld note palette, same shape as a
  melody's `notes` array. C major pentatonic in octave 4: `C4 D4 E4 G4 A4`.
  `placeholder: true`. This is editable data per §3 — rewrite it and every slot
  retunes with no code change.
- **`autoload/palette.gd`** (`Palette`) — loads the palette at boot and exposes
  `midi_for_slot(slot) -> int` (−1 for an empty/malformed slot) and
  `slot_count()`. Input and world objects reference a *slot*, never a pitch.
- **`autoload/synth.gd`** (`Synth`) — the runtime synth (§7.1). Generates tones
  with `AudioStreamGenerator` rather than sample files, so tuning is exact by
  construction (`NoteNames.to_frequency()`) and nothing needs re-recording when
  the palette changes. Real instrument samples can replace it behind the bus
  later. Listens to `NoteBus.note_played`.
- **`scenes/player/note_input.gd`** (`NoteInput`) — a Node2D child of the player
  that reads `note_slot_0`–`note_slot_4` and calls
  `NoteBus.play_note(midi, global_position)`. Kept off `player.gd` so movement
  stays movement (§7.3). Held keys pluck once (`is_action_pressed` ignores key
  repeat).

### Synth design

- Single `AudioStreamGenerator`; an **8-voice pool** mixed in one buffer (not one
  player per voice) so the summed output can be scaled to avoid clipping — the
  per-player bus mixer could not do that for us.
- Per voice: **linear attack** (~6 ms, removes the onset click) then
  **exponential decay** (`decay_tau` 0.28 s). A finished voice frees itself; a
  9th note steals the oldest.
- **Clipping control:** the mix is divided by `sqrt(active voice count)`, so a
  chord stays louder than a single note without exceeding full scale (§7.1). The
  divisor is eased toward its target so a starting/ending voice doesn't jump the
  scale of notes already sounding and click.
- Tunable `@export`s on the autoload: `voice_gain` (0.22), `master_gain` (0.9),
  `attack` (0.006), `decay_tau` (0.28). Waveform is a plain sine — a deliberate
  placeholder; the owner will replace the sound later.

### Bug found and fixed

Notes triggered but produced **silence**. Diagnosed by instrumenting the chain
(input → bus → synth → output) and measuring the actual output peak, which read
a flat `0.0`. Cause: the envelope returns `0.0` at the very start of the attack
ramp (age 0), and the voice-cleanup check `if env <= 0.0: free the voice`
couldn't tell that apart from the `0.0` at the *end* of the decay — so every
voice was freed on its first sample. Fixed by only freeing past the attack:
`if env <= 0.0 and _age[v] >= attack`. Everything upstream was correct.

### Latency

The generator buffer is the play-to-hear latency (the fill keeps it full, so a
new note waits behind whatever is queued). Reduced `BUFFER_LENGTH` from
**0.1 s → 0.04 s** (~100 ms → ~40 ms) — over two frames of dropout margin at
60 fps while feeling responsive. Godot's own driver output latency (~15 ms
default) and one frame add on top. Lower the const toward ~0.02 for more
snap at the risk of crackle.

**Bluetooth latency is parked**, not solved: BT codecs add ~100–300 ms
downstream of Godot, unreachable by any synth-side lever. A calibration *offset*
could only realign timing *judgment*, not make sound arrive sooner — and it's
only worth building if `timing_matters` is ever unshelved (the design currently
rejects rhythm-sync, §6/§11). The Step 2 ring is the real mitigation: instant
visual feedback that masks the felt lag.

---

## Step 2 — the visible note

### What was built

- **`scripts/music/note_colors.gd`** (`NoteColors`) — a **pure** static helper
  alongside `note_names.gd` and `melody_matcher.gd` (§4 pure seam: no nodes, no
  signals, unit-testable without the engine). Implements §6's "colour is
  load-bearing" rule: **pitch class → hue** (the twelve semitones wrap the hue
  wheel), **octave → brightness**. `color_for_midi(midi) -> Color`. Every note
  visual in the game routes through this one mapping.
- **`scenes/fx/note_ring.gd`** (`NoteRing`) — a self-contained Node2D that
  expands and fades over ~0.5 s, then frees itself. **Ease-out cubic** radius
  (fast at the attack, slowing as it fades, to match the sound's shape, §7.4).
  Purely presentational — it never decides what a note affects. Colour from
  `NoteColors`.
- **`autoload/note_visuals.gd`** (`NoteVisuals`) — listens to
  `NoteBus.note_played` (symmetric with Synth) and spawns a ring at the note's
  world position. Rings live in world space and stay put as the player moves on.

### Colour mapping specifics

- Default `HUE_OFFSET` = 0.0 → **C sits at hue 0 (red)**, ascending. A single
  const rotates the whole language. (This intentionally does *not* match the
  hand-authored `color_sequence` in `door_test_01.json`, which is owner data
  read by nothing, §5 — the code follows §6's rule.)
- `SATURATION` 0.85; octave brightness from `BASE_VALUE` 0.9 at
  `REFERENCE_OCTAVE` 4, `VALUE_PER_OCTAVE` 0.08, clamped `[0.5, 1.0]`.
- The five starter notes (C D E G A, all octave 4) land on five distinct hues at
  equal brightness.

### Ring tunables (`note_ring.gd`)

`max_radius` (22 px), `duration` (0.5 s), `line_width` (2 px). Drawn above room
tiles (`z_index` 5), not antialiased for pixel-art crispness, alpha fades
linearly while the radius eases.

---

## Cross-cutting: rules honored

- **The one rule (§3):** no pitch/melody in any `.gd`. The verification grep is
  clean — the only literal note names are in `tests/` and `note_names.gd`
  doc-comments, both exempt.
- **`effects_enabled()` (§6):** audio and visuals always play; only gameplay
  effects gate. Neither Synth nor NoteVisuals checks it — that check belongs on
  the Step 4 resonator, the first thing that produces a gameplay-visible effect.
- **Categories are not in M1:** every note gets the same generic treatment.
- **Nothing built ahead:** no doors, collection, melody locks, instrument-state
  entry, saves, or art.

---

## Testing & verification

- Unit tests (`tests/test_melody_matcher.gd`, run headless): **29 passed, 0
  failed.** Added this milestone: `test_frequencies` (protects tuning, since the
  synth relies on `to_frequency()`) and `test_note_colors` (pins the colour
  mapping's invariants — same pitch class shares a hue, different pitch class
  differs, higher octave is brighter).
- `godot --headless --import`: clean, no parse errors.
- **Step 1 audio:** confirmed audible on device by the owner.
- **Step 2 visuals:** implemented and passing the automated checks, but not yet
  eyeballed on screen — a rendered ring can only be verified by running it.

---

## Files

**New**

```
data/palettes/starter.json
autoload/palette.gd
autoload/synth.gd
autoload/note_visuals.gd
scripts/music/note_colors.gd
scenes/fx/note_ring.gd
scenes/player/note_input.gd
```

**Modified**

```
project.godot                    # autoloads: + Palette, Synth, NoteVisuals
scenes/player/player.tscn        # added NoteInput child under Player
tests/test_melody_matcher.gd     # + test_frequencies, + test_note_colors
```

Autoload order is now: `InputConfig, NoteBus, MelodyLibrary, Palette, Synth,
NoteVisuals`.

---

## What's left in M1

- **Step 3 — the note bar:** five slots along the bottom of the screen, colour
  first and note name second, flashing on press (§7.6).
- **Step 4 — the resonator:** a block tuned to a palette *slot* (not a pitch).
  Correct note in range lights in its colour; wrong note gives a small dull
  shake. Must respect `effects_enabled()` — the first thing in the game that
  does (§7.5).
- **The gate:** once all four exist, the real question is whether playing feels
  good on its own. If it doesn't, the core design gets rethought before anything
  is built on top.

## How to run

```
godot --headless --import                                # parse check
godot --headless --script tests/test_melody_matcher.gd    # unit tests
godot .                                                    # play; 1–5 = notes
```
