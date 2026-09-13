# M2 — One door, data-driven · Specification

**Status:** Step 0 complete (colour-by-category); Steps 1–4 specified, not built.
**Authority:** `CLAUDE.md` is the contract; this spec expands §7 into buildable
detail and must stay consistent with it. Where they disagree, `CLAUDE.md` wins —
say so rather than following this file. The external design doc
(`music-game-design-doc.md`) wins over both.

---

## 1. Goal and the gate

The player picks up notes, walks to a door, enters an instrument state, and the
door opens when the right melody is played on the notes they hold.

**The milestone gate (the whole point):** change the melody in a door's JSON
file, relaunch, and **the door wants a different tune, with a different number of
gems, with no code touched.** Everything else in M2 is scaffolding for that one
demonstration (§7).

Two supporting design rules that the gate depends on:
- **The one rule (§3):** no pitch, melody, or musical pattern in any `.gd` file.
  World objects reference a note **id** or a palette **slot**; the
  keyboard→pitch map and the note categories are data.
- **No failure cost (§6):** infinite retries, no penalty. The length ramp makes
  guessing self-limiting.

---

## 2. Scope

### In scope (the five steps of §7)
0. Colour by category (`NoteRegistry` + pure `NoteColors`). **Done.**
1. Note collection — start empty, walk into a pickup, gain a playable slot.
2. The instrument state — an overlay entered at a door; piano input; no world
   effects; free instant cancel.
3. `MelodyLock` and the door — gems that show structure and progress; open on
   match; reset on wrong note.
4. Prove the swap — edit melody JSON, relaunch, door changes, no code.

### Explicitly NOT in M2 (§7, verbatim constraints)
Multiple rooms · backtracking · the note-acquisition graph · the solvability
validator · **ability behaviours for notes** (categories are data only; nothing
acts on them) · combat · art · story · menus · saves · a melody journal · world
clue delivery (chiming crystals, murals, humming creatures — that is M3) ·
rhythm/timing matching · the HUD resize.

If a task appears to require one of these, stop and say so (§11). Do not route
around a non-goal.

---

## 3. Architecture — file map

New and changed files, by responsibility. `[done]` marks Step 0.

```
autoload/
  note_registry.gd     [done] Loads data/notes.json; id/midi -> {category,index}; colour resolution.
  note_inventory.gd    [step 1, replaces palette.gd] What the player owns, by pitch class + slots.
  input_config.gd      [step 2, modify] + `interact` action; + piano actions from keyboard_layout.json.
scripts/music/
  note_colors.gd       [done] PURE. color(category, index, octave) -> Color.
scenes/
  objects/
    resonator.gd       [done, modified] now colours through NoteRegistry.
    note_pickup.gd/.tscn  [step 1, new] @export note_id; walk-in to collect.
    door.gd/.tscn         [step 3, new] @export melody_id; gems; open-on-unlock.
    melody_lock.gd        [step 3, new] Accumulates played notes -> MelodyMatcher -> unlocked.
  player/
    note_input.gd      [step 2, modify] Overworld number-row OR instrument-state piano, by mode.
    player.gd          [step 2, modify] Suspend movement while instrument state is active.
  ui/
    note_bar.gd        [done, modified] colours through NoteRegistry; grows as slots fill.
    instrument_overlay.gd  [step 2, new] CanvasLayer scrim; fades on instrument_state_changed.
  main.gd              [step 2, modify] Instantiates the instrument overlay.
data/
  notes.json           [done, new] The note registry (3 placeholder notes); source of truth for category/colour.
  keyboard_layout.json [step 2, new] Physical key -> semitone offset for the piano layout.
  melodies/
    door_test_01.json  [step 3, modify] Becomes the 1-note first door.
    door_test_02.json  [step 3, new] The 3-note ordered door.
  palettes/starter.json  [step 1, retired] Player starts empty; fixed palette no longer loaded.
tests/
  test_melody_matcher.gd [done, modified] Category-colour assertions replace pitch-colour ones.
docs/
  m2-spec.md           This file.
  m2-progress.md       [step 4, new] The completion record (§12).
```

### The seams that do not move
- **Pure seam (§4):** `note_names.gd`, `melody_matcher.gd`, `note_colors.gd`
  stay node-free, signal-free, engine-free, unit-tested. New M2 decision logic
  goes here or nowhere; the matcher already owns the "does the door open"
  decision, so `MelodyLock` is thin glue with no logic of its own to duplicate.
- **The bus (§4):** everything reactive listens to
  `NoteBus.note_played(midi, source)` and `NoteBus.instrument_state_changed(active)`.
  No new bus signals are required for M2.
- **Match rules in data (§4):** `MelodyMatcher.evaluate(target, attempt, rules)`
  → `{result, progress}`. Difficulty is tuned by editing a melody's
  `match_rules`, never by a code branch.

---

## 4. Data formats

### 4.1 Note registry — `data/notes.json` (done)

Canonical note list (§5). One note per pitch class (§6), so a played MIDI value
resolves to exactly one note by its pitch class.

```json
{
  "notes": [
    { "id": "n_break", "pitch_class": "C", "category": "destructive", "index": 0 },
    { "id": "n_mend",  "pitch_class": "D", "category": "restorative", "index": 0 },
    { "id": "n_step",  "pitch_class": "E", "category": "movement",    "index": 0 }
  ]
}
```

- `pitch_class` is a letter, not a pitch. `category ∈ {destructive, restorative,
  movement}`. `index` 0–3 places the note within its category's hue arc (§6).
- **Only three notes exist in M2 (§9).** The category assignments are
  clearly-flagged placeholders (a `_placeholder` key in the file states this) —
  a musician's decision, not to be treated as final and not to be extended to
  twelve.

### 4.2 Keyboard layout — `data/keyboard_layout.json` (new, Step 2)

The instrument-state piano map, in data so it stays rebindable and holds no
pitch in code (§3 corollary). Maps physical keys to **semitone offsets** from a
base octave; the pitch is `base_octave`'s C plus the offset.

```json
{
  "base_octave": 4,
  "keys": [
    { "action": "piano_c",  "physical_key": "Z", "semitone": 0 },
    { "action": "piano_cs", "physical_key": "S", "semitone": 1 },
    { "action": "piano_d",  "physical_key": "X", "semitone": 2 },
    { "action": "piano_ds", "physical_key": "D", "semitone": 3 },
    { "action": "piano_e",  "physical_key": "C", "semitone": 4 },
    { "action": "piano_f",  "physical_key": "V", "semitone": 5 },
    { "action": "piano_fs", "physical_key": "G", "semitone": 6 },
    { "action": "piano_g",  "physical_key": "B", "semitone": 7 },
    { "action": "piano_gs", "physical_key": "H", "semitone": 8 },
    { "action": "piano_a",  "physical_key": "N", "semitone": 9 },
    { "action": "piano_as", "physical_key": "J", "semitone": 10 },
    { "action": "piano_b",  "physical_key": "M", "semitone": 11 },
    { "action": "piano_oct_c", "physical_key": "Q", "semitone": 12 }
  ]
}
```

This is the §6 layout: white keys `Z X C V B N M`, black keys `S D` / `G H J`,
`Q` row for the octave above. It collides with `WASD` on purpose — it only
exists where movement is suspended. The `Q` row is a starting subset; more
octave-up keys can be added as data without code change. `physical_key` names map
to `Key.KEY_*` physical keycodes (§6: bindings follow key position).

### 4.3 Door melodies — `data/melodies/*.json`

Existing schema (§5), with `hint.color_sequence` **dropped** — colours derive
from the notes themselves, so a hand-authored sequence was a second source of
truth. M2 uses two doors whose notes are drawn only from the three owned pitch
classes (C, D, E):

`door_test_01.json` — the first door, one note (§6 length ramp: 1 note held → 1
note wanted):

```json
{
  "id": "door_test_01",
  "display_name": "First Door",
  "notes": ["C4"],
  "rhythm": [1],
  "key": "C", "mode": "major", "tempo_bpm": 90,
  "match_rules": { "order_matters": true, "timing_matters": false,
                   "octave_matters": false, "allow_transposition": false },
  "finale_role": "unassigned",
  "placeholder": true
}
```

`door_test_02.json` — a three-note ordered door (proves order and gem count):

```json
{
  "id": "door_test_02",
  "display_name": "Second Door",
  "notes": ["C4", "D4", "E4"],
  "rhythm": [1, 1, 1],
  "key": "C", "mode": "major", "tempo_bpm": 90,
  "match_rules": { "order_matters": true, "timing_matters": false,
                   "octave_matters": false, "allow_transposition": false },
  "finale_role": "unassigned",
  "placeholder": true
}
```

`octave_matters` is `false` (§6: octave is expressive range, not a separate
collectible), so playing `C5` satisfies a `C4` door — the matcher already
handles this; `MelodyLock` passes the rules through untouched.

---

## 5. Component specifications

Signatures are the contract between steps. Autoloads are `Node`s (impure glue);
pure logic stays in the seam.

### 5.1 `NoteRegistry` (autoload) — done

```gdscript
func by_id(id: String) -> Dictionary       # {id, pitch_class, category, index} or {}
func by_midi(midi: int) -> Dictionary      # note whose pitch class == midi's, or {}
func color_for_midi(midi: int) -> Color    # resolves category/index, hands to NoteColors; NEUTRAL if unknown
func reload() -> void
```

### 5.2 `NoteColors` (pure `class_name`) — done

```gdscript
static func color(category: String, index: int, octave: int) -> Color
const NEUTRAL := Color(0.2, 0.2, 0.24)
const CATEGORY_ARC := { "destructive": [0.00, 0.15], "restorative": [0.25, 0.50], "movement": [0.60, 0.90] }
```

Hue from the category's arc walked by index; octave sets brightness; unknown
category → `NEUTRAL`. Looks nothing up (§4).

### 5.3 `NoteInventory` (autoload, replaces `Palette`) — Step 1

What the player owns, by pitch class, plus the overworld slot assignment. The
number-row palette (`note_slot_0`–`4`) reads slots from here; world objects
reference a **slot** (§3 corollary), which is why the resonators keep working
with no change beyond the autoload rename.

```gdscript
const MAX_SLOTS := 5
const OVERWORLD_OCTAVE := 4      # the octave the number-row plays; instrument state can go elsewhere

signal note_collected(note_id: String)

func collect(note_id: String) -> bool     # add to inventory + next free slot; false if owned or full
func has(note_id: String) -> bool         # owns this note id
func owns_pitch_class(pc: int) -> bool     # 0..11; used to filter piano input (Step 2)
func note_id_for_slot(slot: int) -> String # "" if empty
func midi_for_slot(slot: int) -> int       # slot's note at OVERWORLD_OCTAVE, or -1
func slot_count() -> int                   # number of FILLED slots (the note bar grows as this grows)
func owned_note_ids() -> Array[String]
```

Behaviour:
- **Starts empty.** No fixed palette is loaded; `data/palettes/starter.json` is
  retired. This is the design doc's cold open (§7 Step 1): nothing to play until
  the first pickup.
- `collect(id)` resolves the id through `NoteRegistry` (rejects an unknown id),
  refuses a duplicate pitch class or a full inventory, assigns the note to the
  lowest free slot, and emits `note_collected`.
- `midi_for_slot` returns the slot note's pitch class at `OVERWORLD_OCTAVE`,
  computed from `NoteRegistry.by_id(...).pitch_class` via `NoteNames`. No pitch
  literal (§3).
- `slot_count()` returns filled slots, so `note_bar` shows one swatch per owned
  note and gains one on each pickup.

**Callers to update (Step 1):** `resonator.gd` and `note_bar.gd` reference
`Palette.*`; repoint to `NoteInventory.*` (same method names). `note_bar._ready`
should also connect `NoteInventory.note_collected` → `queue_redraw` so a new slot
appears immediately.

### 5.4 `NotePickup` (`scenes/objects/note_pickup.tscn` + `.gd`) — Step 1

```gdscript
@export var note_id: String        # e.g. "n_break"; resolved through NoteRegistry — NO pitch here
```

- An `Area2D` + a small drawn shape tinted by the note's colour
  (`NoteRegistry.by_id(note_id)` → `NoteColors.color(category, index,
  NoteInventory.OVERWORLD_OCTAVE)`).
- On the player's body entering: `NoteInventory.collect(note_id)`; if it
  returns `true`, play a brief pickup flash and `queue_free()`. If `false`
  (already owned), do nothing and remain — harmless.
- **Walk-in collection**, not interact — the interact key is reserved for doors
  (Step 2), and §7 Step 1's done-condition is "walk into a pickup."

**M2 pickups placed in the test room:** three, granting `n_break` (C),
`n_mend` (D), `n_step` (E) — one per category, so collection visibly changes the
note bar's colours.

### 5.5 Input additions — `input_config.gd` — Step 2

- Register **`interact`** (physical `E`, plus `KEY_ENTER` as a convenience). Used
  to enter/exit the instrument state at a door.
- Load `data/keyboard_layout.json`; register each `keys[]` entry as an action
  bound to its physical key. Expose:

```gdscript
func piano_actions() -> Array[String]      # the registered piano action names
func piano_semitone(action: String) -> int # semitone offset for an action
func piano_base_octave() -> int            # keyboard_layout.base_octave
```

Keeping the semitone map in `InputConfig` (which already owns the `InputMap`
built in code) gives one loader for both the binding and the offset lookup. No
pitch literal enters code — offsets are semitone integers from data.

### 5.6 `note_input.gd` (player component) — Step 2

Two modes, switched by `NoteBus.instrument_state_changed`:

- **Overworld** (`effects_enabled()` true): read `note_slot_0`–`4`; on
  just-pressed play `NoteInventory.midi_for_slot(slot)` via
  `NoteBus.play_note(midi, player.global_position)` when `midi >= 0`.
- **Instrument state** (active): read `InputConfig.piano_actions()`; for each
  just-pressed, `midi = (piano_base_octave + 1) * 12 + piano_semitone(action)`;
  play only if `NoteInventory.owns_pitch_class(NoteNames.pitch_class(midi))` —
  **unowned keys do nothing** (§7 Step 2). Overworld number-row is suppressed in
  this mode (the two layouts collide by design, §6).

Notes still sound and still spawn rings in both modes (`Synth` and `NoteVisuals`
do not gate on `effects_enabled()`); only gameplay effects are suppressed.

### 5.7 `player.gd` — Step 2

Suspend movement while `NoteBus.instrument_state_active`: zero the velocity and
skip movement input for the duration. Model on Ocarina of Time — the world keeps
running behind the overlay, no scene change, no fade to black (§6).

### 5.8 `InstrumentOverlay` (`scenes/ui/instrument_overlay.gd`, a `CanvasLayer`) — Step 2

- Instantiated as a child of the main scene by `main.gd` (avoids editing
  `main.tscn`).
- Connects `NoteBus.instrument_state_changed(active)`: fades a translucent scrim
  in when active, out when not. The world renders and runs behind it.
- Fade is fast (≈0.1–0.15s) so cancel feels instant and free. **Envelope trap
  (§10):** track fade direction/target, not just the current alpha — an alpha of
  0 at the start of a fade-in must not be mistaken for the end of a fade-out.

### 5.9 `MelodyLock` (`scenes/objects/melody_lock.gd`, a `Node`) — Step 3

Thin glue over the pure matcher — it holds no matching logic of its own (§4).

```gdscript
@export var melody_id: String

signal unlocked
signal progress_changed(progress: int, total: int)
signal mismatch

func arm() -> void      # resolve target+rules from MelodyLibrary; clear attempt; start listening
func disarm() -> void   # stop listening; clear attempt
func total() -> int     # target note count (drives gem count)
```

- `arm()`: look up the melody via `MelodyLibrary.get(melody_id)`, build
  `target = NoteNames.list_to_midi(melody.notes)` and `rules =
  melody.match_rules`, clear the attempt buffer, and begin reacting to
  `NoteBus.note_played` — but only while `NoteBus.instrument_state_active` and
  this lock is armed (only the entered door's lock is armed at a time).
- On each played note: append `midi` to the attempt; call
  `MelodyMatcher.evaluate(target, attempt, rules)`:
  - `MATCH` → emit `unlocked`, then `disarm()`.
  - `IN_PROGRESS` → emit `progress_changed(result.progress, total())`.
  - `MISMATCH` → emit `mismatch`, clear the attempt, emit
    `progress_changed(0, total())`.
- No penalty on mismatch (§6): the buffer just resets.

### 5.10 `Door` (`scenes/objects/door.tscn` + `.gd`) — Step 3

```gdscript
@export var melody_id: String     # forwarded to the child MelodyLock
```

- Composes a `MelodyLock` child (its `melody_id` set from the door's).
- An `Area2D` interaction zone tracks whether the player is inside.
- **Enter:** player in-zone presses `interact` while `NoteBus.effects_enabled()`
  (i.e. not already in an instrument state) → `NoteBus.set_instrument_state(true)`
  and `lock.arm()`.
- **Exit / cancel:** `interact` again while active → `set_instrument_state(false)`,
  `lock.disarm()`, reset gems. Instant and free (§6).
- **Gems:** drawn along the door frame, **one per melody note**. Each gem is
  tinted by its target note's colour (`melody.notes[i]` → MIDI →
  `NoteRegistry.color_for_midi`), so the door shows its structure — how many
  notes, their categories, and progress — at top-down scale. `progress` gems
  render lit (full colour); the rest render dim (a darkened version of the same
  colour, so the target colours stay visible). This is hint enough for M2; **no
  world clue-delivery is built** (§7 Step 3 — that is M3).
  - Update on `lock.progress_changed(progress, total)`.
  - On `lock.mismatch`: brief soft-negative cue (a short desaturated flash or
    small shake), then all gems dim. No penalty.
  - **Envelope trap (§10):** a gem's lit/dim state is driven by the discrete
    `progress` count, not a free-running envelope; any flash animation must track
    its own phase.
- **Open:** on `lock.unlocked` the door opens and **stays open** (disable its
  blocking collision, switch to the open visual) and calls
  `set_instrument_state(false)`.

Gems reveal the target colours on purpose in M2 (§7 Step 3): early doors are
"tutorials wearing a door costume" (§6), and with a one-note first door there is
nothing to hide. A hidden-hint door is a deliberate later override, not M2.

---

## 6. End-to-end flow (Steps 1–3 assembled)

```
Start empty (no notes, empty note bar)
  → walk into pickup(n_break) → NoteInventory.collect → note bar gains a C swatch
  → (collect n_mend, n_step similarly)
Walk into a Door's zone → press interact
  → Door: effects_enabled()? yes → NoteBus.set_instrument_state(true) + lock.arm()
  → player.gd suspends movement; InstrumentOverlay fades in; note_input switches to piano
Play piano keys (owned pitch classes only)
  → NoteBus.play_note(midi, pos) → Synth sounds it, NoteVisuals rings it (always),
    Resonator ignores it (effects_enabled() == false)
  → MelodyLock appends midi, evaluates:
       IN_PROGRESS → progress_changed → Door lights the next gem
       MISMATCH    → mismatch → Door flashes + resets gems (no penalty)
       MATCH       → unlocked → Door opens & stays open → set_instrument_state(false)
Press interact again before matching → set_instrument_state(false) + lock.disarm() (free cancel)
```

---

## 7. Test plan

Consistent with the repo's pattern: the **pure seam is unit-tested**; the
autoload/scene glue is verified by running the game (the owner), because the
`--script` SceneTree harness does not load autoloads or scenes (§4, and the
existing tests never touch `Palette`/`NoteBus`).

- **Unit (pure, `tests/test_melody_matcher.gd`, `godot --headless --script`):**
  - `NoteColors` category-arc mapping — **done** (6 assertions: ordered arcs,
    index climbs the arc, octave is brightness not hue, twelve distinct hues,
    unknown category → desaturated).
  - `MelodyMatcher` — unchanged; already covers order, octave tolerance,
    unordered, transposition, progress counting, over-length, empties. These are
    the door's decision logic, so `MelodyLock` needs no separate matcher test.
  - Add a case for any **new pure function** a step introduces (§10). None is
    currently planned — `NoteInventory` slot assignment and `MelodyLock` glue are
    impure autoload/scene code. If slot-assignment logic grows non-trivial,
    extract it to a pure helper and test it rather than leaving it unpinned.
- **Run verification (owner):** each step's done-condition below is checked by
  running `godot .` and watching the described behaviour. Report these as
  run-verified, never as "tests pass," for anything visual or runtime.

Every change starts with `godot --headless --import` (parse check) and ends with
the full unit run green and the §3 one-rule guard clean.

---

## 8. Step ladder — build order and done-conditions

Build one step at a time, stopping after each so the owner can run it (§7).

- **Step 0 — Colour by category. [DONE]**
  Done: existing M1 visuals still work, now coloured by category; tests pin the
  new mapping. (32 unit assertions pass; boots clean; one-rule guard clean.)
- **Step 1 — Note collection.**
  Done: you start empty, walk into a pickup, and the note bar gains a slot you
  can immediately play (number row).
- **Step 2 — The instrument state.**
  Done: walk to a door, press interact, play freely on the piano layout with no
  world effects, and walk away mid-phrase with no penalty. Overlay fades over the
  running world; unowned keys are silent.
- **Step 3 — MelodyLock and the door.**
  Done: a door with a 1-note melody (`door_test_01`) opens; a door with a 3-note
  melody (`door_test_02`) requires the right order; gems light one at a time and
  reset on a wrong note.
- **Step 4 — Prove the swap.**
  Edit `data/melodies/door_test_0*.json` (change the notes and their count),
  relaunch, confirm the door now wants a different melody with a different number
  of gems, **no code changed.** Write the result into `docs/m2-progress.md`, and
  update `CLAUDE.md` §2/§8 and `README.md` in the same change (§12).

---

## 9. Decisions recorded

Design calls made while specifying/building M2, kept here so a fresh session
inherits the reasoning (§12; ADR-style, since the repo has no `docs/decisions/`).

- **D0-a — Callers route through `NoteRegistry`, not `NoteColors`.** §7 Step 0
  said the ring/bar/resonator "need no edits," but keeping `NoteColors` pure
  (§4, the hard rule) forces the category lookup into `NoteRegistry`, so each
  caller switched `NoteColors.color_for_midi` → `NoteRegistry.color_for_midi`
  (one line each). Purity beats the convenience; the alternative (lookup inside
  `NoteColors`) breaks §4 and was rejected.
- **D0-b — Unassigned pitch classes render `NEUTRAL`.** The starter palette held
  five pentatonic notes but §9 caps M2 at three registry notes, so `G`/`A` have
  no category. Rather than touch the palette in Step 0 (that is Step 1's job),
  unknown pitch classes fall back to a desaturated neutral. Step 1 retires the
  fixed palette entirely, so the gap closes then.
- **D1 — `NoteInventory` replaces `Palette` and starts empty.** The number-row
  palette becomes a view of what the player owns; slots fill on collection. Keeps
  the §3 slot corollary and the resonators working with only a rename.
- **D2 — Piano semitone map lives in `InputConfig`.** One loader owns both the
  `InputMap` binding and the semitone lookup, so `keyboard_layout.json` is read
  once and no pitch enters code.
- **D3 — Gems reveal target colours in M2.** Per §7 Step 3, the gems' colours are
  the hint; hidden-hint doors are a deliberate later override, out of M2 scope.

---

## 10. Open questions — do not decide these (from §9)

Implement nothing that assumes an answer; ask if a task seems to need one.

- **Which pitch classes map to which category** — a musician's decision. M2 uses
  three clearly-flagged placeholders; do not fill in all twelve.
- **What each note actually does in the world** — categories are data in M2; no
  behaviour attaches. Do not build ability behaviours.
- **Combat** — whether it exists at all, and which approach.
- **The convergent finale** — every door melody is meant to be a fragment of one
  larger piece, but code must never assume this; if the idea were dropped,
  nothing should break. `key`/`mode`/`finale_role` stay read-by-nothing (§5).
- **How the player learns a melody** (heard on approach, inscribed, discovered
  elsewhere) — that is M3's question. M2's gems are the only hint.

---

## 11. Verification of the gate

M2 is complete when, from a clean launch: start empty → collect the three notes
→ open `door_test_01` with one C → open `door_test_02` with C‑D‑E in order → then
**edit a door melody's `notes` in JSON, relaunch, and watch the door demand the
new tune with the new gem count, with zero code changes** — and that swap is
written up in `docs/m2-progress.md`. That single demonstration is the milestone
(§7).
