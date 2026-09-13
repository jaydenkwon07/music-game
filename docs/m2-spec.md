# M2 — One door, data-driven · Specification

**Status:** Steps 0–2 built. `interact` (space) is now the single world verb
(D8): pickups are collected with it, and — until Step 3's Door owns entry — it
also enters the instrument state as a temporary fallback when nothing is in
range. Steps 3–4 specified, not built.
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
1. Note collection — start empty, walk onto a pickup and press `space`, gain a playable slot.
2. The instrument state — an overlay entered at a door with `space`; home-row piano input; no world
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
  input_config.gd      [step 2, modify] + `interact`/`cancel`/octave actions; + palette and piano actions from keyboard_layout.json.
scripts/music/
  note_colors.gd       [done] PURE. color(category, index, octave) -> Color.
scenes/
  objects/
    resonator.gd       [done, modified] now colours through NoteRegistry.
    note_pickup.gd/.tscn  [step 1, new] @export note_id; walk-in to collect.
    door.gd/.tscn         [step 3, new] @export melody_id; gems; open-on-unlock.
    melody_lock.gd        [step 3, new] Accumulates played notes -> MelodyMatcher -> unlocked.
  player/
    note_input.gd      [step 2, modify] Overworld palette OR instrument-state piano, by mode.
    player.gd          [step 2, modify] Suspend movement while instrument state is active.
  ui/
    note_bar.gd        [done, modified] colours through NoteRegistry; grows as slots fill.
    instrument_overlay.gd  [step 2, new] CanvasLayer scrim; fades on instrument_state_changed.
  main.gd              [step 2, modify] Instantiates the instrument overlay.
data/
  notes.json           [done, new] The note registry (3 placeholder notes); source of truth for category/colour.
  keyboard_layout.json [step 2, new] Piano semitone map + per-layout palette keys.
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

Both key maps, in data so they stay rebindable and no pitch enters code (§3
corollary). One file, one loader.

**`piano`** maps physical keys to **semitone offsets** from a base octave; the
pitch is `base_octave`'s C plus the offset plus the current octave shift.
**`palette`** holds the overworld slot keys per movement layout.

```json
{
  "piano": {
    "base_octave": 4,
    "keys": [
      { "action": "piano_00", "physical_key": "A",         "semitone": 0 },
      { "action": "piano_01", "physical_key": "W",         "semitone": 1 },
      { "action": "piano_02", "physical_key": "S",         "semitone": 2 },
      { "action": "piano_03", "physical_key": "E",         "semitone": 3 },
      { "action": "piano_04", "physical_key": "D",         "semitone": 4 },
      { "action": "piano_05", "physical_key": "F",         "semitone": 5 },
      { "action": "piano_06", "physical_key": "T",         "semitone": 6 },
      { "action": "piano_07", "physical_key": "G",         "semitone": 7 },
      { "action": "piano_08", "physical_key": "Y",         "semitone": 8 },
      { "action": "piano_09", "physical_key": "H",         "semitone": 9 },
      { "action": "piano_10", "physical_key": "U",         "semitone": 10 },
      { "action": "piano_11", "physical_key": "J",         "semitone": 11 },
      { "action": "piano_12", "physical_key": "K",         "semitone": 12 },
      { "action": "piano_13", "physical_key": "O",         "semitone": 13 },
      { "action": "piano_14", "physical_key": "L",         "semitone": 14 },
      { "action": "piano_15", "physical_key": "P",         "semitone": 15 },
      { "action": "piano_16", "physical_key": "SEMICOLON", "semitone": 16 }
    ]
  },
  "palette": {
    "default_layout": "wasd",
    "wasd":   ["H", "J", "K", "L", "SEMICOLON"],
    "arrows": ["A", "S", "D", "F", "G"]
  }
}
```

**The piano layout is white keys on the home row** (§6): `A S D F G H J K L ;`
as C D E F G A B C D E, with black keys above on the `Q` row —
`W E _ T Y U _ O P`. `R` and `I` are **deliberately absent**, exactly where a
piano has no black key between E–F and B–C. That gap is self-teaching; do not
"fill it in."

Range is C4–E5, seventeen semitones, before any octave shift. `physical_key`
names map to `Key.KEY_*` physical keycodes, so positions stay correct on AZERTY
and Dvorak.

**M2 defaults to the `wasd` palette.** The `arrows` variant ships in data and is
reachable through the existing Tab debug swap, which must now switch **movement
and palette together** — they are one layout choice, not two.

#### Two collisions this layout introduces

**1. Palette and piano actions share physical keys.** In `wasd`, the palette
sits on `H J K L ;`, which are also piano white keys A B C D E. This is
harmless — the two sets are read in mutually exclusive modes (§4.x `note_input`)
— but `InputConfig._key_owner()` from M0 treats any duplicate physical key as a
conflict. **Scope the duplicate guard per action group** (movement / palette /
piano / system) rather than globally, or `rebind()` will refuse valid bindings
and report phantom conflicts.

**2. Movement keys are piano keys.** `W A S D` are C♯, C, D and E in the
instrument state. Safe only because movement is suspended there — which is the
whole reason the instrument state exists (§6). If anything ever lets the player
move and play simultaneously, this breaks immediately.

#### Other bindings (Step 2)

| Action | Key | Notes |
|---|---|---|
| `interact` | `SPACE` | Enter/exit the instrument state. Reachable from either movement layout. |
| `cancel` | `ESCAPE` | Layered: exits the instrument state when active; reserved for pause otherwise. |
| `octave_down` | `[` | Shifts the piano map down an octave. |
| `octave_up` | `]` | Shifts it up. |

**Octave shift is in scope for M2.** `octave_matters` is false so it changes
nothing mechanically — but one fixed octave feels like a cage the first time a
player tries to actually play something at a door, and it is four lines. Clamp
the shift to ±2 and reset it to 0 on entering the instrument state, so a door
attempt always starts from a known place.

**Never hardcode a key's printed letter.** Any on-screen hint reads its label
from `DisplayServer.keyboard_get_label_from_physical()`. Hints must also be
**mode-aware**: in `arrows` mode `A S D F G` are palette slots in the overworld
and white keys C–G in the instrument state.

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
overworld palette reads slots from here; world objects
reference a **slot** (§3 corollary), which is why the resonators keep working
with no change beyond the autoload rename.

```gdscript
const MAX_SLOTS := 5
const OVERWORLD_OCTAVE := 4      # the octave the palette plays; instrument state can go elsewhere

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
- `midi_for_slot` returns the slot note's pitch class at `OVERWORLD_OCTAVE` (the overworld palette is fixed to one octave; only the instrument state shifts),
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

- An `Interactable` (§ D8) + a small drawn shape tinted by the note's colour
  (`NoteRegistry.by_id(note_id)` → `NoteColors.color(category, index,
  NoteInventory.OVERWORLD_OCTAVE)`).
- `interact(player)`: `NoteInventory.collect(note_id)`; if it returns `true`,
  play a brief pickup flash and `queue_free()`. `can_interact()` returns false
  once collected, so a duplicate pickup stays put rather than vanishing.
- **Collected with `interact` (space)**, not walk-in — the single world verb
  (D8) covers pickups, doors, NPCs and hints alike. This **reverses** the
  original walk-in decision; Step 1's done-condition changed to match (§8).

**M2 pickups placed in the test room:** three, granting `n_break` (C),
`n_mend` (D), `n_step` (E) — one per category, so collection visibly changes the
note bar's colours.

### 5.5 Input additions — `input_config.gd` — Step 2

- Register **`interact`** (physical `SPACE`), **`cancel`** (`ESCAPE`), and **`octave_down`/`octave_up`** (`[` / `]`). Used
  to enter/exit the instrument state at a door.
- Load `data/keyboard_layout.json`; register each `piano.keys[]` entry as an action, and the `palette` keys for the active movement layout
  bound to its physical key. Expose:

```gdscript
func piano_actions() -> Array[String]      # the registered piano action names
func piano_semitone(action: String) -> int # semitone offset for an action
func piano_base_octave() -> int            # keyboard_layout.piano.base_octave
func palette_actions() -> Array[String]    # slot actions for the active layout
func octave_shift() -> int                 # current shift, clamped -2..2, reset on enter
```

Keeping the semitone map in `InputConfig` (which already owns the `InputMap`
built in code) gives one loader for both the binding and the offset lookup. No
pitch literal enters code — offsets are semitone integers from data.

### 5.6 `note_input.gd` (player component) — Step 2

Two modes, switched by `NoteBus.instrument_state_changed`:

- **Overworld** (`effects_enabled()` true): read `InputConfig.palette_actions()`; on
  just-pressed play `NoteInventory.midi_for_slot(slot)` via
  `NoteBus.play_note(midi, player.global_position)` when `midi >= 0`.
- **Instrument state** (active): read `InputConfig.piano_actions()`; for each
  just-pressed, `midi = (piano_base_octave + octave_shift() + 1) * 12 + piano_semitone(action)`;
  play only if `NoteInventory.owns_pitch_class(NoteNames.pitch_class(midi))` —
  **unowned keys do nothing** (§7 Step 2). The overworld palette is suppressed in
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
- **Enter:** player in-zone presses `interact` (`space`) while `NoteBus.effects_enabled()`
  (i.e. not already in an instrument state) → `NoteBus.set_instrument_state(true)`
  and `lock.arm()`.
- **Exit / cancel:** `interact` or `cancel` while active → `set_instrument_state(false)`,
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
Walk into a Door's zone → press space
  → Door: effects_enabled()? yes → NoteBus.set_instrument_state(true) + lock.arm()
  → player.gd suspends movement; InstrumentOverlay fades in; note_input switches to piano
Play piano keys (owned pitch classes only)
  → NoteBus.play_note(midi, pos) → Synth sounds it, NoteVisuals rings it (always),
    Resonator ignores it (effects_enabled() == false)
  → MelodyLock appends midi, evaluates:
       IN_PROGRESS → progress_changed → Door lights the next gem
       MISMATCH    → mismatch → Door flashes + resets gems (no penalty)
       MATCH       → unlocked → Door opens & stays open → set_instrument_state(false)
Press space or escape before matching → set_instrument_state(false) + lock.disarm() (free cancel)
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
- **Step 1 — Note collection. [BUILT]**
  Done: you start empty, walk onto a pickup and press `space` to collect it, and
  the note bar gains a slot you can immediately play on the palette keys.
  (Collection is via the single `interact` verb, D8 — not walk-in.)
- **Step 2 — The instrument state. [BUILT — run-verify pending]**
  Done: walk to a door, press space, play freely on the home-row piano layout with no
  world effects, and walk away mid-phrase with no penalty. Overlay fades over the
  running world; unowned keys are silent.
  **Built with one deviation:** the Door does not exist yet (Step 3), so the
  instrument state is entered by a **temporary fallback in `Interactor`** — when
  `interact` (space) is pressed with no Interactable in range, it toggles the
  instrument state on; `interact`/`cancel` while active toggles it off. Clearly
  marked for Step 3's Door to replace with a proximity-gated entry paired with
  `lock.arm()/disarm()`. The palette also migrated off the number row onto the
  home-row keys from `keyboard_layout.json` (§4.2), and the Tab debug swap now
  switches movement + palette together. Run-verification (the piano feel, the
  overlay, movement suspend, collecting on space) is the owner's, per §7.
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
- **D1 — `NoteInventory` replaces `Palette` and starts empty.** The overworld
  palette becomes a view of what the player owns; slots fill on collection. Keeps
  the §3 slot corollary and the resonators working with only a rename.
- **D2 — Piano semitone map lives in `InputConfig`.** One loader owns both the
  `InputMap` binding and the semitone lookup, so `keyboard_layout.json` is read
  once and no pitch enters code.
- **D3 — Gems reveal target colours in M2, as scaffolding.** The gems stand in
  for world clue delivery that does not exist yet (crystals, murals, humming
  creatures — all M3). This is **not** the intended design: the standing rule is
  that doors show structure and never content (§6). The revealed colours come
  out at M3 when clue delivery arrives. Recorded so a later session doesn't
  inherit revealed gems as a decision.
- **D4 — Interact is `space`, not `E`.** `E` was fine when notes lived on the
  number row, but with the palette on home row `space` is the only key either
  hand reaches without moving. `escape` is layered: it exits the instrument
  state when active, and is otherwise reserved for pause.
- **D5 — Home-row piano, not the tracker row (Session 7).** White keys moved
  from `Z X C V B N M` to `A S D F G H J K L ;`. Two reasons: the hand rests on
  home row so the thumb falls on `space` without shifting down and forward, and
  range grows from thirteen semitones to seventeen. `R` and `I` land unbound
  exactly where a piano has no black key, which teaches the layout for free.
  Cost: this is no longer the FL Studio / Renoise convention, so prior DAW
  habits don't carry — accepted, since that convention only ever helped players
  who had used a tracker.
- **D6 — The palette mirrors the movement layout, and M2 defaults to `wasd`.**
  Notes sit under the hand that isn't moving: `H J K L ;` for WASD, `A S D F G`
  for arrows. Reverses the earlier fixed-number-row plan — a player only ever
  uses one layout, so consistency across both buys nothing while home row buys
  a hand position. The number row is now free and reserved for loadout swapping.
- **D7 — Duplicate physical keys are legal across action groups.** Palette and
  piano actions intentionally share keys. The M0 `_key_owner()` guard must be
  scoped per group or it will reject valid bindings (see §4.2).
- **D8 — `interact` (space) is the single world verb (Session 8).** The owner's
  call: one key does all interaction — collecting a note, and later opening a
  door, talking to an NPC, reading a hint. This **reverses** §5.4's original
  walk-in pickup (Step 1's done-condition changed with it). The seam is an
  `Interactable` base (`Area2D` + `interact()`/`can_interact()`) that joins an
  `IN_RANGE_GROUP` while the player is inside it; a player-side `Interactor` fires
  the nearest in-range one on `interact`, reading the group rather than holding
  references (§4). `NotePickup` is the first implementer; the Step 3 Door and any
  M3 NPC/hint are just more implementers — **none of those behaviours are built,
  only the seam.** Until the Door exists, the `Interactor` also carries the
  temporary instrument-state entry (enter when nothing is in range; `interact`/
  `cancel` exits while active), which the Door replaces.

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
