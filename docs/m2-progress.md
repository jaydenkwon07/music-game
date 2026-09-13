# M2 — One door, data-driven · Completion record

**Status:** complete. **Date:** 2026-09-13. Runs clean on Godot 4.7.2.
**Spec:** `docs/m2-spec.md` (the buildable expansion of `CLAUDE.md` §7).

---

## The gate (the whole point of M2)

> Change the melody in a door's JSON file, relaunch, and the door wants a
> different tune, with a different number of gems, with no code touched.

**Met.** Verified directly: rewriting `door_test_01.json` from one note (`C4`) to
three (`D4 E4 C5`) makes its door report **3 gems** and target `[62, 64, 72]`
with **zero code changes** — the gem count is `melody.notes.size()` and the
target is `MelodyLibrary.get_midi(melody_id)`, both pure data. The §3 one-rule
guard is clean, so no pitch, melody or pattern lives in any `.gd` file; a door
references only a melody **id**, and the melody is entirely JSON.

The owner has not needed to run the manual relaunch demonstration; the mechanism
is proven by construction and by the headless check above.

---

## What shipped, by step

- **Step 0 — Colour by category.** `note_colors.gd` takes `(category, index,
  octave)`; `NoteRegistry` (autoload) loads `data/notes.json` and resolves
  `id`/`midi → {category, index}`. `NoteColors` stays pure — callers route their
  category lookup through `NoteRegistry`, not the colour helper (spec D0-a).
- **Step 1 — Note collection.** `NoteInventory` (autoload) replaces the retired
  fixed `Palette`: the player starts **empty** and gains a slot per pickup, by
  pitch class. `NotePickup` drops three notes (C/D/E, one per category) in the
  room. The note bar grows a swatch on each collection.
- **Step 2 — The instrument state.** `data/keyboard_layout.json` holds the piano
  semitone map and the per-layout palette keys, so no pitch enters code (§3
  corollary). `InputConfig` registers the **home-row piano**, the **palette**
  (mirrored to the movement hand, off the number row), and `interact` / `cancel`
  / octave actions, with the duplicate-key guard **scoped per action group** so
  palette and piano may share physical keys (spec D7). `note_input` plays the
  palette in the overworld and the piano — filtered to **owned pitch classes** —
  in the instrument state. Movement is suspended there; a translucent
  `InstrumentOverlay` fades over the still-running world (Ocarina-of-Time model).
  Tab now swaps movement **and** palette together.
- **Step 3 — MelodyLock and the door.** `MelodyLock` is thin glue over the pure
  `MelodyMatcher` (no matching logic of its own): armed at a door, it accumulates
  played notes and emits `progress_changed` / `mismatch` / `unlocked`. `Door` is
  an `Interactable` composing a lock; its gems show **structure only** — one per
  note, tinted by the target note's colour, lit one at a time by progress — never
  which notes (spec D3). A wrong note resets the attempt with **no penalty** (§6);
  the full melody opens the door for good. `door_test_01` is the 1-note first
  door; `door_test_02` is the 3-note ordered door.
- **Step 4 — Prove the swap.** The gate above.

---

## The unified interact verb (owner decision, spec D8)

Mid-M2 the owner made `interact` (**space**) the single world verb: it collects a
note, and at a door it enters the instrument state and arms that door's lock. The
same `Interactable` seam is what future NPCs, hints and further doors implement —
**none of those behaviours are built, only the seam.** This reversed Step 1's
original walk-in pickup. A temporary "space enters the instrument state anywhere"
fallback existed between Steps 2 and 3 to make Step 2 runnable before a door
existed; Step 3's Door took over entry and the fallback was removed.

---

## Architecture added

```
autoload/
  note_registry.gd     [Step 0] data/notes.json -> {category,index}; colour resolution
  note_inventory.gd    [Step 1] what the player owns, by pitch class + slots (replaced palette.gd)
  input_config.gd      [Step 2] + piano/palette (from keyboard_layout.json), interact/cancel/octave; per-group key guard
scenes/
  ui/instrument_overlay.gd   [Step 2] CanvasLayer scrim, fades on instrument_state_changed
  player/interactor.gd       [interact verb] fires the nearest in-range Interactable on `interact`
  objects/interactable.gd    [interact verb] base: Area2D + interact()/can_interact(), IN_RANGE_GROUP
  objects/note_pickup.gd     [Step 1] an Interactable; collect on `interact`
  objects/melody_lock.gd     [Step 3] played notes -> MelodyMatcher -> unlocked/progress/mismatch
  objects/door.gd            [Step 3] Interactable composing a MelodyLock; structure gems; open-on-unlock
data/
  notes.json           [Step 0] 3 placeholder notes; category/colour source of truth
  keyboard_layout.json [Step 2] piano semitone map + per-layout palette keys
  melodies/door_test_01.json  [Step 3] the 1-note first door
  melodies/door_test_02.json  [Step 3] the 3-note ordered door
```

The pure seam (`note_names.gd`, `melody_matcher.gd`, `note_colors.gd`) and the
bus (`NoteBus`) were **not** changed — M2 needed no new bus signals; the Step 0
signal `instrument_state_changed` from M0/M1 carried the whole instrument state.

---

## Verification

- **Unit:** 32 assertions in `tests/test_melody_matcher.gd` pass (`NoteColors`
  category arcs + the unchanged `MelodyMatcher` cases). Per the repo's strategy,
  autoload/scene glue is not unit-tested (the `--script` harness loads neither).
- **§3 one-rule guard:** clean — no pitch in any `.gd` outside the two exempt
  files.
- **Headless boot:** clean, no errors/warnings; 2 melodies loaded.
- **Headless lifecycle checks (throwaway scenes, since removed):** interaction
  routing (Area2D detects the player, `interact` collects, range clears on exit);
  door lifecycle (arm → correct melody unlocks with octave tolerance and exits
  the state; wrong note resets with no penalty; ordered door needs the right
  order; an un-armed door ignores overworld notes); and the swap gate above.
- **Owner run-verify:** Steps 1–3 confirmed on-run ("works"). Anything visual or
  runtime (piano feel, overlay, gems, placement) is the owner's source of truth.

---

## Deviations and open items carried forward

- **D8 (unified interact) reversed the spec's walk-in pickup.** Recorded in
  `docs/m2-spec.md` §9 (D8) and §5.4.
- **The door's physical blocking gates nothing yet.** A `StaticBody2D` (disabled
  on open) is wired per spec §5.10, but there is one room and nothing behind the
  door until M3.
- **Which pitch class maps to which category is still the owner's call** (§9).
  M2 uses three clearly-flagged placeholders (C/D/E); the other nine are not
  assigned and must not be.
- **M1's aesthetic gate is still deferred** — the synth is a placeholder sine;
  the gate runs the first time a real instrument voice exists (`CLAUDE.md` §2).
- **M3 prerequisite:** the camera does not clamp to room bounds, so out-of-bounds
  void is visible; `Camera2D` limits fix it and `test_room.gd` knows its size.
