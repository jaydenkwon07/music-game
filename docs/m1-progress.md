# M1 — The Note Toy: complete

**Status: M1 complete** (build), 2026-09-12. All four build steps are
implemented, verified, committed (`b3b8923`) and pushed. The milestone's
aesthetic gate is **deferred, not failed** — see [M1 outcome](#m1-outcome--the-gate)
at the bottom.

M1 is the "note toy" milestone (CLAUDE.md §7): the player can play notes, each
makes a sound and a visible effect. Built in four steps, each stopped at for the
owner to run:

| Step | What | State |
|---|---|---|
| 1 | Smallest thing that makes sound | Done, confirmed audible on device |
| 2 | Make a note visible (expanding ring + shared colour) | Done, confirmed on screen |
| 3 | The note bar | Done, confirmed on screen |
| 4 | The resonator | Done, confirmed on screen |

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
  `placeholder: true`. Editable data per §3 — rewrite it and every slot retunes
  with no code change.
- **`autoload/palette.gd`** (`Palette`) — loads the palette at boot; exposes
  `midi_for_slot(slot) -> int` (−1 for an empty/malformed slot) and
  `slot_count()`. Input and world objects reference a *slot*, never a pitch.
- **`autoload/synth.gd`** (`Synth`) — the runtime synth (§7.1). Generates tones
  with `AudioStreamGenerator` rather than sample files, so tuning is exact by
  construction (`NoteNames.to_frequency()`) and nothing needs re-recording when
  the palette changes. Real instrument samples replace it behind the bus later.
- **`scenes/player/note_input.gd`** (`NoteInput`) — a Node2D child of the player
  reading `note_slot_0`–`note_slot_4` and calling
  `NoteBus.play_note(midi, global_position)`. Kept off `player.gd` (§7.3). Held
  keys pluck once.

### Synth design

- Single `AudioStreamGenerator`; an **8-voice pool** mixed in one buffer so the
  summed output can be scaled to avoid clipping.
- Per voice: **linear attack** (~6 ms) then **exponential decay**
  (`decay_tau` 0.28 s). A finished voice frees itself; a 9th note steals the
  oldest.
- **Clipping control:** the mix is divided by `sqrt(active voice count)` (§7.1),
  the divisor eased so a starting/ending voice doesn't click.
- Tunable `@export`s: `voice_gain` (0.22), `master_gain` (0.9), `attack`
  (0.006), `decay_tau` (0.28). Waveform is a plain sine — a deliberate
  placeholder; the owner replaces the sound later.

### Bug found and fixed

Notes triggered but produced **silence** (measured output peak flat `0.0`). The
envelope returns `0.0` at the start of the attack ramp (age 0), and the
voice-cleanup check `if env <= 0.0: free the voice` couldn't tell that apart
from the `0.0` at the *end* of the decay — so every voice was freed on its first
sample. Fixed with `if env <= 0.0 and _age[v] >= attack`.

### Latency

`BUFFER_LENGTH` reduced **0.1 s → 0.04 s** (~100 ms → ~40 ms) — over two frames
of dropout margin at 60 fps while feeling responsive. Lower toward ~0.02 for
more snap at the risk of crackle.

**Bluetooth latency is parked**, not solved: BT codecs add ~100–300 ms
downstream of Godot, unreachable by any synth-side lever. A calibration offset
could only realign timing *judgment*, not make sound arrive sooner — and it's
only worth building if `timing_matters` is ever unshelved (rhythm-sync is
rejected, §6/§11). The Step 2 ring is the real mitigation: instant visual
feedback masking the felt lag.

---

## Step 2 — the visible note

- **`scripts/music/note_colors.gd`** (`NoteColors`) — a **pure** static helper
  alongside `note_names.gd`/`melody_matcher.gd` (§4). Implements §6's "colour is
  load-bearing" rule: **pitch class → hue** (twelve semitones wrap the hue
  wheel), **octave → brightness**. `color_for_midi(midi) -> Color`. Every note
  visual routes through this one mapping.
- **`scenes/fx/note_ring.gd`** (`NoteRing`) — a self-contained Node2D that
  expands (ease-out cubic radius, fast at the attack then slowing, §7.4) and
  fades over ~0.5 s, then frees itself. Purely presentational.
- **`autoload/note_visuals.gd`** (`NoteVisuals`) — listens to
  `NoteBus.note_played` and spawns a ring at the note's world position. Rings
  live in world space and stay put as the player moves on.

Colour specifics: default `HUE_OFFSET` 0 → **C sits at hue 0 (red)**, ascending;
`SATURATION` 0.85; octave brightness `BASE_VALUE` 0.9 at `REFERENCE_OCTAVE` 4,
`VALUE_PER_OCTAVE` 0.08, clamped `[0.5, 1.0]`. The five starter notes land on
five distinct hues, confirmed on screen (C red → D yellow → E green → G blue →
A violet).

---

## Step 3 — the note bar

- **`scenes/ui/note_bar.gd`** (`NoteBar`, a `Control` under the `UI`
  CanvasLayer) — one slot per palette note along the bottom: a **colour swatch**
  (via `NoteColors`) with the **note name** centred beneath (`NoteNames.to_name`,
  computed — no literal note names in code). **Flashes** a slot toward white when
  its note plays (matched by midi), fading over `flash_time`. Presentational
  only. Confirmed on screen; colour-first / name-second reads as intended (§7.6).
- Tunables: `slot_size` (28×24), `slot_gap` (4), `margin_bottom` (6),
  `flash_time` (0.18).

---

## Step 4 — the resonator

- **`scenes/objects/resonator.gd`** (`Resonator`, a Node2D) — a block tuned to a
  palette **slot** (not a pitch, §3 corollary), resolving its pitch via
  `Palette.midi_for_slot(slot)`. On a played note it **gates on
  `NoteBus.effects_enabled()` first** — the first thing in the game to do so —
  then checks range against the bus's `source`: **right note → brightens to full
  colour**; **wrong note → a small decaying shake**. At rest it shows a dim
  version of its colour so its tuning still reads (§6).
- Three test resonators are spawned from `main.gd` (a script edit, no `.tscn`
  change), tuned to slots 0/2/4 (C/E/A). Confirmed on screen: correct note
  lights, wrong note shakes, out of range does nothing.
- Tunables: `hear_radius` (40), `light_time` (0.45), `shake_time` (0.2),
  `shake_pixels` (2).

---

## Cross-cutting: rules honored

- **The one rule (§3):** no pitch/melody in any `.gd`. The verification grep is
  clean — literal note names only in `tests/` and `note_names.gd` doc-comments,
  both exempt.
- **`effects_enabled()` (§6):** audio and visuals always play; only gameplay
  effects gate. Synth, NoteVisuals and NoteBar do not check it; the resonator
  does — the milestone's first and only gated effect.
- **Categories are not in M1:** every note gets the same generic treatment.
- **Nothing built ahead:** no doors, collection, melody locks, instrument-state
  entry, saves, or art.

---

## Testing & verification

- Unit tests (`tests/test_melody_matcher.gd`, headless): **29 passed, 0 failed.**
  Added this milestone: `test_frequencies` (protects tuning) and
  `test_note_colors` (pins the colour mapping's invariants). Steps 3–4 added no
  new pure functions, so no new tests — `NoteBar` and `Resonator` are nodes
  reusing already-tested helpers.
- `godot --headless --import`: clean, no parse errors.
- All four steps confirmed on device/screen by the owner.

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
scenes/ui/note_bar.gd
scenes/objects/resonator.gd
scenes/player/note_input.gd
```

**Modified**

```
project.godot                    # autoloads: + Palette, Synth, NoteVisuals
scenes/player/player.tscn        # added NoteInput child under Player
scenes/main.tscn                 # added NoteBar under the UI CanvasLayer
scenes/main.gd                   # spawns three test resonators
tests/test_melody_matcher.gd     # + test_frequencies, + test_note_colors
```

Autoload order: `InputConfig, NoteBus, MelodyLibrary, Palette, Synth,
NoteVisuals`. Committed and pushed as `b3b8923` on `main`.

---

## M1 outcome — the gate

**Build: complete and verified.** No mechanical or visual issues; every step
runs and behaves as specified, confirmed by the owner.

**Gate: deferred, not failed.** M1's gate (§7) asks whether *sitting in a gray
room playing notes feels good on its own*. At the current placeholder fidelity
that question can't be answered honestly: in a game whose only verb is playing a
note, the feel is bound up in the *sound*, and the synth is a deliberate plain
sine — a stand-in for the real instrument voices the owner composes later (the
synth was built to swap out behind the bus, §7.1). So the aesthetic verdict
waits on real audio.

Important distinction, so the plan stays intact: this is a **sound-fidelity
deferral, not a failure of the placeholder-first bet.** The mechanics and the
box-and-colour visuals are fine at placeholder fidelity — the owner's
assessment. The placeholder-first philosophy still holds, and **M3 still relies
on it** (placeholder everything, a stranger getting the loop in 5–10 min). What
M1 shows is narrower: "does *playing a note* feel good" is an audio question a
sine can't settle; "does the *structure* work" (M3) is a different question that
placeholders can still answer.

**Marked complete** on 2026-09-12 by owner decision. The feel judgment is
revisited once real instrument sound exists.
