# M3 — The vertical slice · Progress record

**Status:** built; headless verification green. **The milestone gate (§11) — a
fresh player getting the loop unprompted in 5–10 min — is pending the owner's
run-verify.** **Date:** 2026-09-14. Runs clean on Godot 4.7.2.
**Spec:** `docs/m3-spec.md` (the buildable expansion of the design doc's M3
section and §§3.6, 3.7, 7.4, 7.5).

This record is written at build-complete so a fresh session inherits what exists
and what remains. It will be promoted to "complete" only once the owner confirms
the play-through gate.

---

## The gate (the whole point of M3)

> A stranger plays the slice start to finish in 5–10 minutes and understands the
> loop without being told — collect notes, play a door's melody on the notes you
> hold, learn the melody from the world, and realize a late note opens an early
> door.

**Not yet met — it is a play-through judgement only the owner can make.** What is
proven headlessly is that the slice is *solvable and correctly wired*: the
`scripts/validate_rooms.py` reachability + length-ramp check passes, and an
integration smoke test confirmed transitions, the fixed-screen camera, and
state persistence across room re-instancing. The felt question — does the loop
land — is the owner's to answer on `godot .`.

---

## The slice as built

Four fixed-screen rooms, two doors, one deliberate backtrack:

- **Room A (Threshold, start):** collect `n_step` (E); **D2** (`door_tutorial`,
  `[E]`) gates the east exit and opens at once with the note just collected; **D1**
  (`door_backtrack`, `[C,D,E]`) gates the north exit to the reward and cannot be
  played yet. A chime beside each door teaches its melody.
- **Room B (Gallery):** collect `n_mend` (D); free gaps west→A and east→C.
- **Room C (Deep):** collect `n_break` (C) — the note D1 needs; dead-ends back to B.
- **Room D (Reward):** reachable only after returning to A and opening D1.

The forced path teaches pickup → chime → door → transition in order, then makes
the map knowledge pay off in the backtrack. D1 is three notes (not two) so Room
B's `n_mend` is load-bearing and the door is not brute-forceable (spec D-M3-8).

---

## What shipped, by step

- **Step 0/1 — World host + rooms from data + camera clamp.** `world.gd`/
  `world.tscn` (the new main scene) is the persistent host for the player, UI and
  instrument overlay; it owns `enter_room(room_id, entry_id)`, which frees the old
  room, instances the new one, places the player at a named entry, and clamps the
  camera to the room's bounds. `RoomGraph` (autoload) loads `data/rooms.json` plus
  the per-room geometry and runs the §5.3 consistency check at boot. `Room`
  (`class_name Room`) paints a `TileMapLayer` from the geometry grid — **collision
  from the tileset**, no per-wall `StaticBody2D`. `main.*` and `test_room.*` are
  deleted.
- **Step 2 — Transitions.** `RoomLink` (an `Area2D` in an unmarked gap) forwards a
  `transition_requested` signal up through its `Room` to `World` (World is a scene,
  not an autoload, so it is not globally addressable). A per-link arm delay plus
  re-arm-on-exit prevents an arrival gap from bouncing the player straight back.
- **Step 3 — Doors gate real exits.** A gated link's `Door` sits `DOOR_INSET` tiles
  inside from it, blocking the 1-tile corridor to it; opening disables the blocker
  so the link becomes reachable — the door never teleports (spec D-M3-4). Door gems
  now tint by **category only**, showing structure (count, categories, progress)
  but never the specific note (spec D-M3-3). Opened doors persist via `WorldState`.
- **Step 4 — Clue delivery.** `MelodyChime` (an `Interactable`) plays a door's
  melody through the existing synth and pulses each note's colour in order,
  re-strikeable — the owner's chosen clue vector (spec D-M3-2). This retires M2's
  scaffolding: content now lives on the chime, structure on the door.
- **Step 5 — Validator + CI.** `scripts/validate_rooms.py` (standalone Python) does
  the reachability fixpoint + length-ramp + referential-integrity checks;
  `.github/workflows/validate.yml` runs it on push/PR. Godot unit tests stay local.

---

## Architecture added

```
autoload/
  room_graph.gd        [Step 1] loads rooms.json + geometry; boot consistency check (§5.3)
  world_state.gd       [Step 1] opened doors + taken pickups, by id; survives re-instancing (§6.3a)
scenes/
  world.gd/.tscn       [Step 1] persistent host; enter_room; per-room camera clamp (new main scene)
  rooms/room.gd        [Step 1] Room base: paints TileMapLayer from data, instances contents
  rooms/gray_tileset.gd[Step 1] code-built 2-tile gray TileSet (floor + collidable wall)
  rooms/room_a..d.tscn [Step 1] thin scenes over Room + room_id
  objects/room_link.gd [Step 2] Area2D transition; signal-up-through-Room; bounce guard
  objects/melody_chime.gd [Step 4] Interactable clue: plays the melody + colour pulses
  objects/door.gd      [modified] gates a real gap; category-only gems; WorldState persistence
  objects/note_pickup.gd [modified] WorldState persistence (taken notes don't reappear)
data/
  rooms.json           [Step 1] the room graph (exits/entries/notes/gates), validator-readable
  rooms/room_a..d.json [Step 1] per-room geometry: grid + entries/links/pickups/chimes
  melodies/door_tutorial.json, door_backtrack.json  [replace door_test_0*.json]
scripts/validate_rooms.py       [Step 5] solvability validator
.github/workflows/validate.yml  [Step 5] CI
```

The pure seam (`note_names`, `melody_matcher`, `note_colors`), the bus
(`NoteBus`), `MelodyLock`, `NoteInventory` and the input layer were **not**
changed — M3 added no matching logic and no new bus signals.

---

## Verification

- **Unit:** 32 assertions in `tests/test_melody_matcher.gd` still pass (the pure
  seam was untouched).
- **§3 one-rule guard:** clean — no pitch in any `.gd` outside the two exempt files
  (M3's new code refers to notes and melodies only by id).
- **Validator:** `OK — 4 rooms reachable, 2 doors solvable, ramp holds.`
- **Headless boot:** clean, no errors/warnings.
- **Integration smoke (throwaway autoload, since removed):** boots into room_a with
  the camera == viewport (fixed screen, no scroll); A→B→A transitions land at the
  right entries; an opened door reopens open; a taken pickup does not reappear.
- **Owner run-verify:** **pending** — the play-through gate (§11) and everything
  visual/felt (transitions, doors staying open on return, chimes) are the owner's
  source of truth on `godot .`.

---

## Deviations and decisions

- **Gray `TileSet` built in code**, not authored in the editor (spec §6.7 assigned
  it to the owner). Done to deliver a runnable slice without blocking on an
  in-editor step; `Room` reads its tile size back from the built TileSet, so an
  editor-authored TileSet with real art drops in at M5 with no other change.
- **Rooms are fixed one-screen at 20px tiles → 16×9 = exactly 320×180.** An earlier
  cut used 16px/20×12 (320×192), which forced a few pixels of pointless vertical
  scroll; the owner asked for a room that matches the game ratio, so the tile size
  moved to 20px for an exact fixed screen (spec §6.7 / D-M3-5 anticipated this).
- **Door positions are derived** from each gated link by edge-detecting "inward"
  and insetting `DOOR_INSET` tiles (the geometry puts `door` on the link, not a
  separate placement).
- **`RoomGraph.geometry()`** was added beyond the §6.1 API, and rooms load by the
  convention path `res://scenes/rooms/<id>.tscn`.

---

## Notes carried forward

- **Future rooms can vary in size.** The fixed 16×9 one-screen room is the M3
  slice's *choice*, not a system limit: the camera clamps to whatever
  `Room.bounds()` reports, so any room larger than 320×180 in either axis already
  scrolls and clamps correctly. Later acts should mix one-screen frames (the
  common case, per design doc §3.7) with larger scrolling rooms freely — no code
  change is needed, only larger geometry grids. (Owner direction, 2026-09-14.)
- **The other three clue-delivery vectors** (mural, humming creature, cross-room
  fragment) remain endorsed and deferred (spec D-M3-2 / design doc §3.6); only the
  chime is built.
- **No note ability behaviours, combat, art, or the cold-open darkness** — all M4+/
  M5, deliberately absent (spec §2).
- **`CLAUDE.md` §2/§8 and `README.md` are not yet updated** — that promotion waits
  on the owner's play-through, per spec Step 5 and §12 of `CLAUDE.md`.
