# M3 — The vertical slice · Specification

**Status:** Not started. This spec expands the design doc's M3 section (§11) and
§§3.6, 3.7, 7.4, 7.5 into buildable detail. Nothing in this document is built
yet.
**Authority:** `CLAUDE.md` is the contract; this spec expands it into buildable
detail and must stay consistent with it. Where they disagree, `CLAUDE.md` wins —
say so rather than following this file. The external design doc
(`music-game-design-doc.md`, V6) wins over both.

---

## 1. Goal and the gate

Three to five connected rooms, two doors, and one deliberate backtrack — an
obstacle in the start room that requires a note found deep in the map. Placeholder
everything: gray boxes, placeholder music, no art.

**The milestone gate (the whole point):** someone unfamiliar plays the slice
start to finish in **5–10 minutes and understands the loop without being told** —
that notes are collected, that doors want a melody played on the notes you hold,
that the melody is learned in the world, and that a note found late can open
something passed early.

This is **the decision point for the whole project** (design doc §11): if the
slice is fun, everything after is production; if it isn't, that is learned for the
price of a month rather than a year. It must not be collapsed into M5.

Two framing rules this milestone leans on:
- **M3 is layout, not art (§11, `[J]`).** Deliberate gray boxes — geometry chosen
  for flow and sightlines — not scattered collision-test blocks. Tilesets,
  sprites, lighting and the cold-open darkness are **M5**. If art creeps in, M3
  stops being the cheap checkpoint.
- **Doors are not transitions (§3.7).** An ordinary exit is an unmarked gap you
  walk through. A door is a framed structure blocking that gap. Opening a door
  **unblocks the exit; it does not move the player** — walking through is a
  separate, deliberate beat. If every boundary were a door, the player would hit a
  puzzle every twelve seconds (the §4.5 failure this avoids).

---

## 2. Scope

### In scope

1. **Rooms as scenes with a `TileMapLayer`**, collision from the tileset (not
   hand-placed `StaticBody2D`s). `test_room.gd` is deleted.
2. **Named entry points** per room; **transitions are edge `Area2D`s** handing off
   to the next room's matching entry.
3. **`data/rooms.json`** — the room graph, in data so the validator runs outside
   Godot (§7.5).
4. **Camera clamped to room bounds** (§3.7), which removes the out-of-bounds void.
5. **The solvability validator** (§7.4) — reachability + the length ramp — running
   in CI.
6. **World clue delivery** arrives as a **re-strikeable chime object**; M2's
   scaffolding gems **stop revealing their target note colours** (§3.6, D-M3-3).
7. **The 4-room slice** of §3: two doors (one tutorial, one backtrack gate) and one
   deliberate backtrack, built from the three existing placeholder notes.

### Explicitly NOT in M3

Real art, tilesets, sprites, lighting · **the cold-open darkness / notes-as-light**
(that is M5, design doc §4.1) · **note ability behaviours** (categories stay data
only; nothing acts on them — M5) · combat and bosses (M4+) · a map (§3.7 parked) ·
camera zoom (§3.7 parked) · a melody **journal** (the re-strikeable chime removes
the need in M3) · the other three clue-delivery vectors — **mural / humming
creature / cross-room fragment** (endorsed by the owner, deferred; see D-M3-2) ·
saves · menus · settings · story · a second playable character · the HUD resize
(Q23).

If a task appears to require one of these, stop and say so (§11 of `CLAUDE.md`). Do
not route around a non-goal.

---

## 3. The slice — the concrete layout

Four rooms (within the 3–5 range), two doors, one backtrack. It reuses the three
M2 notes — `n_step` (E, movement), `n_mend` (D, restorative), `n_break` (C,
destructive) — so no §9 pitch/category/behaviour question is touched.

```
        ┌─────────┐
        │ Room D  │   Reward — reachable only after D1 opens
        └────┬────┘
     D1 ▓  (wants [C, D, E])
        ┌────┴────┐   D2 ▒            ┌─────────┐   free    ┌─────────┐
        │ Room A  │──(wants [E])──────│ Room B  │───gap─────│ Room C  │
        │Threshold│   gated exit E    │ Gallery │           │  Deep   │
        │ spawn   │                   │         │           │         │
        │ +n_step │                   │ +n_mend │           │ +n_break│
        └─────────┘                   └─────────┘           └─────────┘
```

- **Room A — Threshold (start).** Player spawns empty. Collects **`n_step` (E)**,
  the first note — teaching pickup + the interact prompt. **Door D2**
  (`door_tutorial`) gates the east exit to Room B and wants a **1-note melody
  `[E4]`**; the player has just collected E, so it opens at zero cost (design doc
  §3.6, "the first door being a single note does real work"). A **chime** beside D2
  plays `[E]` and teaches clue delivery. Also in the room: **Door D1**
  (`door_backtrack`) gating the north passage to Room D, wanting **`[C4, D4, E4]`** —
  the player cannot play C or D yet, so this plants the backtrack. D1's chime plays
  `[C, D, E]`.
- **Room B — Gallery (connector).** Collects **`n_mend` (D)**. Free gaps west→A and
  east→C. No door (connective tissue stays free, §4.5). May hold one M1 resonator
  as an ambient toy.
- **Room C — Deep (the far room).** Collects **`n_break` (C)** — the note D1 needs.
  A dead-end back to B.
- **Room D — Reward.** Reached only by returning to A with C in hand and opening
  D1. For M3 it is simply a room that was unreachable before; no mechanical payoff
  is required (that is M5's content).

**The intended play sequence** (teaches the whole loop with no text):
spawn → collect E → strike D2's chime → play E at D2 → D2 opens → walk through →
Room B → collect D → Room C → collect C → back through B to A → strike D1's chime
→ play `[C, D, E]` at D1 → D1 opens → Room D.

The backtrack is load-bearing: the obstacle (**D1**) is in the **start** room and
requires a note (**C**) found in the **deepest** room. This is design doc §4.3's
"named, deliberate moment," not an accident of layout.

**Melody lengths honor the ramp (§3.6):** D2 wants 1 note, reachable when the
player holds exactly 1 (E). D1 wants 3 notes, reachable only once the player holds
3 (C, D, E) — the ramp's exact figure, not merely under its ceiling.

**Why D1 is three notes and not two (D-M3-8).** Two reasons, both load-bearing for
the milestone gate:

1. **Otherwise Room B's note does nothing.** With D1 at `[C, E]`, `n_mend` (D) is
   collected in Room B and opens nothing in the entire slice. In a slice whose gate
   is "understands the loop without being told," a collectible that does nothing
   teaches the wrong lesson — and it is the only thing Room B contributes.
2. **Otherwise D1 is guessable in nine tries.** Three notes held and a two-note
   ordered melody is 3² = 9 sequences. A player who mashes opens the slice's
   climactic door in under a minute, skips the chime, skips the backtrack
   realization, and **the gate fails silently** — they finish in time without ever
   learning the loop. Three notes is 3³ = 27, and every collected note becomes
   load-bearing.

---

## 4. Architecture — file map

New and changed files, by responsibility.

```
autoload/
  room_graph.gd        [new] Loads data/rooms.json at boot; lookup rooms/exits/entries/contents by id.
  world_state.gd       [new] Opened doors + taken pickups, by id. Survives room re-instancing (§6.3a).
scenes/
  world.gd/.tscn       [replaces main.gd/main.tscn's room role] Persistent host: Player + UI + Overlay;
                       owns enter_room(room_id, entry_id); sets camera limits per room.
  rooms/
    room.gd            [new, class_name Room] Room base: room_id, bounds(), named entry markers.
                       Builds its TileMapLayer from geometry data (Fork B, D-M3-1).
    test_room.gd/.tscn [DELETED] Replaced by real room scenes/data.
    room_a.tscn … room_d.tscn  [new] The four slice rooms (thin scenes over Room + geometry data).
  objects/
    room_link.gd/.tscn [new] Area2D transition in a gap; @export to_room, to_entry; fires enter_room on body-enter.
    melody_chime.gd/.tscn [new] Interactable clue object; @export melody_id; plays the melody + pulses its colours.
    door.gd            [modify] Blocking StaticBody2D now gates a real gap; gems tint by CATEGORY, not note index.
  player/
    player.tscn        [modify] Camera2D gains per-room limits (set by world.gd), not hardcoded.
data/
  rooms.json           [new] The room graph (§7.5): exits (with optional door gate), entries, note contents, start.
  rooms/
    room_a.json … room_d.json  [new, Fork B] Per-room geometry: gray-box tile grid + spatial placements.
  melodies/
    door_tutorial.json [new] The 1-note first door [E4]. (Renames/replaces door_test_01 role.)
    door_backtrack.json[new] The 3-note backtrack door [C4, D4, E4]. (Replaces door_test_02 role.)
scripts/
  validate_rooms.py    [new] Standalone Python solvability validator (§6); non-zero exit on failure.
tests/
  test_melody_matcher.gd [modify] + a pure-logic reachability/ramp case if any pure GDScript helper is extracted.
.github/workflows/
  validate.yml         [new] Runs validate_rooms.py in CI.
docs/
  m3-spec.md           This file.
  m3-progress.md       [step 5, new] The completion record (§12 of CLAUDE.md).
```

### The seams that do not move

- **Pure seam (§4 of `CLAUDE.md`):** `note_names.gd`, `melody_matcher.gd`,
  `note_colors.gd` stay node-free, signal-free, engine-free, unit-tested. M3 adds
  no matching logic — `MelodyLock` and the door already own the "does it open"
  decision through the matcher. The chime **plays** a melody but decides nothing.
- **The bus (§4):** everything reactive listens to `NoteBus.note_played` and
  `NoteBus.instrument_state_changed`. M3 needs **no new bus signals** — room
  transitions go through the new `RoomGraph`/`World`, not the note bus.
- **Match rules in data (§4):** unchanged. Door difficulty is tuned by a melody's
  `match_rules`, never by code.
- **`Interactable` / `Interactor` (M2, D8):** the chime is a **new implementer** of
  the existing seam — `space` collects, opens, and now strikes a chime, with the
  instrument state still taking precedence and nearest-in-range winning otherwise.
  No new interaction key (design doc §12.1).

---

## 5. Data formats

### 5.1 Room graph — `data/rooms.json` (new)

The abstract graph, in data because the validator runs as standalone Python and
cannot read `.tscn` files (§7.5). Graph only — no geometry, no pixel positions.

```json
{
  "start": { "room": "room_a", "entry": "spawn" },
  "rooms": {
    "room_a": {
      "display_name": "Threshold",
      "notes": ["n_step"],
      "entries": ["spawn", "from_b", "from_d"],
      "exits": [
        { "to": "room_b", "to_entry": "from_a", "door": "door_tutorial" },
        { "to": "room_d", "to_entry": "from_a", "door": "door_backtrack" }
      ]
    },
    "room_b": {
      "display_name": "Gallery",
      "notes": ["n_mend"],
      "entries": ["from_a", "from_c"],
      "exits": [
        { "to": "room_a", "to_entry": "from_b" },
        { "to": "room_c", "to_entry": "from_b" }
      ]
    },
    "room_c": {
      "display_name": "Deep",
      "notes": ["n_break"],
      "entries": ["from_b"],
      "exits": [ { "to": "room_b", "to_entry": "from_c" } ]
    },
    "room_d": {
      "display_name": "Reward",
      "notes": [],
      "entries": ["from_a"],
      "exits": [ { "to": "room_a", "to_entry": "from_d" } ]
    }
  }
}
```

- An exit with a **`door`** id is gated — the player must open that door to pass.
  An exit without one is a **free gap**.
- `notes` lists note ids found in that room (each becomes a `NotePickup`).
- `entries` names the arrival markers; an exit's `to_entry` must be an entry of the
  target room. `display_name` is for the owner/debug only, read by nothing
  gameplay-facing.

### 5.2 Per-room geometry — `data/rooms/<id>.json` (new, Fork B)

Geometry and spatial placement in data, so the whole slice is buildable and
headlessly verifiable without in-editor painting (decision D-M3-1). Kept separate
from `rooms.json` so graph-validation data and rendering data do not entangle.

```json
{
  "room_id": "room_a",
  "size_tiles": [20, 11],
  "grid": [
    "####################",
    "#..................#",
    "#..................#",
    "...(19 more rows)...",
    "####################"
  ],
  "entries": { "spawn": [10, 6], "from_b": [18, 6], "from_d": [10, 2] },
  "links":   [ { "at": [19, 6], "to_room": "room_b", "to_entry": "from_a", "door": "door_tutorial" },
               { "at": [10, 1], "to_room": "room_d", "to_entry": "from_a", "door": "door_backtrack" } ],
  "pickups": [ { "note_id": "n_step", "at": [6, 6] } ],
  "chimes":  [ { "melody_id": "door_tutorial",  "at": [17, 7] },
               { "melody_id": "door_backtrack", "at": [9, 3] } ]
}
```

- **`grid`** is a rectangle of `size_tiles`; `#` is a wall tile, `.` is floor. The
  `Room` script paints these onto a `TileMapLayer` using the shared gray
  `TileSet`. **Collision comes from the tileset** (the wall tile carries a
  collision polygon), never from a per-wall `StaticBody2D` (§2 requirement).
- Positions are **tile coordinates**, not pixels — the `Room` converts (× the tile
  size). No pixel literals leak into placements.
- `links`, `pickups`, `chimes` are the spatial half of what `rooms.json` describes
  logically; a `door` on a link mirrors the `door` on the matching `rooms.json`
  exit. A boot-time check (§5.3) asserts the two agree.
- **Tile size and one-screen fit (a real gotcha).** 320×180 is **not** a whole
  number of 16px tiles vertically (180 / 16 = 11.25). A room the camera should show
  with no void must be **at least the viewport in both dimensions** — with a 16px
  tile that means ≥ 20×12 tiles (320×192), and the camera clamps with a few pixels
  of vertical scroll. For an *exact* fixed one-screen room, pick a tile size that
  divides both 320 and 180 (a divisor of gcd = 20 — e.g. **20px → 16×9 tiles
  exactly**). The tile size is set once on the shared `TileSet` (§6.7); this spec's
  examples use it as a parameter, never a hardcoded 16. A room **smaller** than the
  viewport in either dimension reintroduces the void, so it is disallowed for
  one-screen rooms.

*(If the owner takes Fork A instead — editor-painted `TileMapLayer` scenes — this
file is replaced by hand-authored geometry and `Marker2D`/`RoomLink`/`Chime` nodes
placed in each room `.tscn`; the graph in `rooms.json` and everything else in this
spec is unchanged. See D-M3-1.)*

### 5.3 Consistency between the graph and the rooms

Two data sources describe the same connections (`rooms.json` for the validator,
per-room geometry for placement). They must not drift. On boot, `RoomGraph`
asserts, for every room:
- every `rooms.json` exit has a matching geometry `link` (same `to`/`to_entry`/`door`);
- every geometry `entry` and `link.to_entry` names an entry that exists;
- every referenced `door` melody and `note_id` exists (via `MelodyLibrary` /
  `NoteRegistry`).

A mismatch is a loud startup error, not a silent misroute. The Python validator
(§6) performs the graph half of these checks in CI, independently of the engine.

### 5.4 Door melodies — `data/melodies/*.json`

Two melodies, unchanged schema (M2 §5). Both drawn only from the three owned pitch
classes (C, D, E).

`door_tutorial.json` — the first door, one note (ramp: 1 held → 1 wanted):

```json
{
  "id": "door_tutorial",
  "display_name": "Threshold Door",
  "notes": ["E4"],
  "rhythm": [1],
  "key": "C", "mode": "major", "tempo_bpm": 90,
  "match_rules": { "order_matters": true, "timing_matters": false,
                   "octave_matters": false, "allow_transposition": false },
  "finale_role": "unassigned",
  "placeholder": true
}
```

`door_backtrack.json` — the three-note gate opened after the backtrack:

```json
{
  "id": "door_backtrack",
  "display_name": "Deep Door",
  "notes": ["C4", "D4", "E4"],
  "rhythm": [1, 1, 1],
  "key": "C", "mode": "major", "tempo_bpm": 90,
  "match_rules": { "order_matters": true, "timing_matters": false,
                   "octave_matters": false, "allow_transposition": false },
  "finale_role": "unassigned",
  "placeholder": true
}
```

`octave_matters` stays `false`, so any octave of C/E satisfies the door; the
matcher already handles this and `MelodyLock` passes the rules through untouched.
The M2 files `door_test_01.json` / `door_test_02.json` are replaced by these (their
demonstration job is done; the swap gate they proved is recorded in
`docs/m2-progress.md`).

---

## 6. Component specifications

Signatures are the contract between steps. Autoloads and scene scripts are impure
glue; any non-trivial decision logic is extracted to the pure seam and tested.

### 6.1 `RoomGraph` (autoload) — Step 1

```gdscript
func room(room_id: String) -> Dictionary        # {display_name, notes, entries, exits} or {}
func exits(room_id: String) -> Array            # [{to, to_entry, door}]
func start() -> Dictionary                       # {room, entry}
func has_entry(room_id: String, entry: String) -> bool
func reload() -> void
```

Loads `data/rooms.json` at boot and runs the §5.3 consistency assertions against
`MelodyLibrary` and `NoteRegistry`. Lookups only; no gameplay decisions.

### 6.2 `World` (`scenes/world.gd` + `world.tscn`) — Step 1, replaces `main`'s room role

Persistent host. Children that survive transitions: `Player`, the `UI` CanvasLayer
(`NoteBar`, `DebugLabel`), and the `InstrumentOverlay`. A `RoomHost` node holds the
single active room.

```gdscript
func enter_room(room_id: String, entry_id: String) -> void
```

- `enter_room`: free the current room (if any); instance the target room scene as a
  child of `RoomHost`; place the player at `room.entry_position(entry_id)`; call
  `_apply_camera_limits(room.bounds())`; brief transition guard (§6.4). Idempotent
  re-entry of the same room is allowed (used by the debug reset).
- On `_ready`: `enter_room(RoomGraph.start().room, RoomGraph.start().entry)`.
- `_apply_camera_limits(bounds)`: set the player `Camera2D`'s `limit_left/top/
  right/bottom` from the room bounds in world coordinates (§3.7). A room at or just
  above the viewport in both dimensions clamps to a fixed screen — at 16px that is
  **20×12 tiles (320×192)**, not 20×11, which is 320×176 and four pixels short
  vertically, reintroducing exactly the void §5.2 disallows. Larger rooms scroll and
  clamp.
- The M2 procedural scaffolding (`_spawn_pickups/_spawn_doors/_spawn_resonators`)
  is **removed** — contents now live in room scenes/data.

### 6.3 `Room` (`scenes/rooms/room.gd`, `class_name Room`) — Step 1

```gdscript
@export var room_id: String

func bounds() -> Rect2                     # world-space extent, for the camera clamp
func entry_position(entry_id: String) -> Vector2   # world position of a named entry
```

- On `_ready` (Fork B): read `data/rooms/<room_id>.json`, paint the `grid` onto a
  child `TileMapLayer` using the shared gray `TileSet` (wall tile carries
  collision), and instance `RoomLink`, `NotePickup`, and `MelodyChime` children at
  their tile positions. Entry markers are recorded from the geometry `entries`.
- `bounds()` is `size_tiles × tile_size`.
- Replaces `test_room.gd`, which is deleted. No procedural `StaticBody2D` walls.

### 6.3a `WorldState` (autoload) — Step 1, **required before Step 2**

Rooms are freed and re-instanced on every transition (§6.2), so **nothing a room
contains survives leaving it** unless it is recorded outside the room. The slice
requires the player to return to Room A after opening D2 and taking `n_step`; on a
naive re-instance they would find the door locked again and the note lying there
uncollected.

```gdscript
func is_door_open(door_id: String) -> bool
func mark_door_open(door_id: String) -> void
func is_pickup_taken(note_id: String) -> bool
func mark_pickup_taken(note_id: String) -> void
func reset() -> void                      # debug only
```

- A `Door` consults `is_door_open(melody_id)` on `_ready` and starts open (blocking
  body disabled, open visual) if so; it calls `mark_door_open` on `unlocked`.
- A `NotePickup` consults `is_pickup_taken(note_id)` on `_ready` and frees itself
  immediately if so; it calls `mark_pickup_taken` on a successful collect.
- Keyed by **id**, never by node path or position, so moving a door or pickup in
  the geometry data does not lose its state.
- In-memory only. Saves are not in M3 scope; this is about surviving a transition,
  not a relaunch.

**Chimes need no state** — they are re-strikeable by design (§6.5), so a fresh
instance is correct.

This is small but load-bearing: **backtracking is the milestone**, and backtracking
is precisely the case that exercises it.

### 6.4 `RoomLink` (`scenes/objects/room_link.gd` + `.tscn`, an `Area2D`) — Step 2

```gdscript
@export var to_room: String
@export var to_entry: String
```

- On the player body entering, request the transition from `World`. **`World` is a
  scene, not an autoload** (§6.2), so it is not globally resolvable by name: the
  link emits a `transition_requested(to_room, to_entry)` signal that the `Room`
  forwards up, and `World` connects on instancing. Do not reach for
  `get_tree().get_first_node_in_group()` or a hardcoded node path — both break the
  moment the scene tree is rearranged.
- **Transition guard against bounce-back:** the arriving entry sits a tile *inside*
  the room, away from the far side's link; additionally, links ignore triggers for
  a short interval after a transition and until the player has first *exited* the
  link's area, so materializing near a link does not immediately re-fire it.
- **Doors keep clearance from the boundary (design doc §3.7).** A door sitting
  flush against a room edge means the instrument state is entered at the screen
  edge, where the camera push-in has nowhere to go. Place a gated door **two tiles
  inside** the room from its link, not adjacent to it — so in a 20-wide room a link
  at `[19, 6]` puts its door around `[17, 6]`, with the player standing further in
  still. The §5.2 example placements are illustrative and must be adjusted to honour
  this.
- A `RoomLink` sitting behind a `Door` is only reachable once the door's blocking
  body is disabled — the door is the gate, the link is the reward (§3.7). Walking
  through is a separate beat from opening; the door never teleports the player.

### 6.5 `MelodyChime` (`scenes/objects/melody_chime.gd` + `.tscn`, an `Interactable`) — Step 4

The world's clue delivery (design doc §3.6, Q5) — **the re-strikeable chime**, the
owner's chosen vector for the demo (D-M3-2).

```gdscript
@export var melody_id: String     # the door melody this teaches — NO pitch here (§3)
```

- An `Interactable`: `interact(player)` plays the melody's notes **in sequence**
  through the existing `Synth` (via `NoteBus.play_note(midi, global_position)` on a
  short per-note timer using the melody's `rhythm` for spacing) **and** pulses each
  note's colour in order using `NoteRegistry.color_for_midi` → a small drawn cue.
  Re-strikeable any time; `can_interact()` is always true.
- **No world effect and no gameplay decision** — it is presentational + audio only,
  and reuses `Synth`, `NoteColors`, and the `Interactable` seam. **No new art.**
- Because it is re-strikeable, **no melody journal is needed in M3** — the player
  re-hears a clue on demand rather than memorizing it once (a journal is a deferred
  §3.6 detail, not M3).
- **Envelope trap (§10 of `CLAUDE.md`):** the colour-pulse animation must track its
  own phase/index, not infer position from a bare alpha value.

### 6.6 `Door` changes — Step 3

`Door` keeps its M2 shape (an `Interactable` composing a `MelodyLock`, entered with
`space`, opening on `unlocked`). Two changes:

- **It gates a real gap now.** Its blocking `StaticBody2D` (which gated nothing in
  M2, one room) sits in front of a `RoomLink`. On `unlocked` the body is disabled
  and the door switches to its open visual and **stays open**; the player then
  walks through the link as a separate action (§3.7). The door does **not** move
  the player.
- **Gems show structure, not content (D-M3-3).** In M2 each gem was tinted by its
  target note's *exact* colour — category **and** index — which reveals *which*
  note. In M3 a gem is tinted by the **category** of its target note only (the
  category arc's representative hue), so the door still shows count, progress, and
  *which categories are involved* (structure the design doc §3.6 wants to show) but
  not the specific note (content, which now lives on the chime). Concretely: gem `i`
  uses `NoteColors.color(category_of(melody.notes[i]), CATEGORY_REP_INDEX, octave)`
  rather than the note's own index. Progress lighting and the no-penalty mismatch
  reset are unchanged from M2.

`MelodyLock` is **unchanged** — it already reads only a melody id and is thin glue
over the pure matcher.

### 6.7 The shared gray `TileSet` — Step 1 (owner, one-time)

A trivial two-tile `TileSet` resource: a **floor** tile (no collision) and a
**wall** tile (a full-tile collision polygon), both flat gray placeholders. The
owner creates this once in the editor (~5 minutes; it also teaches the Godot
TileSet workflow). Every room's `TileMapLayer` uses it. Real tilesets and art are
M5.

**Choose the tile size here**, and let it decide one-screen fit (§5.2): 16px keeps
the M1/M2 convention but a one-screen room then scrolls a few pixels vertically;
**20px gives an exact 16×9 one-screen room** and no scroll. Whatever is chosen,
nothing reads a hardcoded tile size — the `Room` builder takes it from the
`TileSet`, and 320×180 stays only in project settings (§3.7, keeps the parked zoom
option alive).

---

## 7. Solvability validator — `scripts/validate_rooms.py` (§7.4)

Standalone Python, **no engine dependency**, run in CI. Reads `data/rooms.json`,
`data/notes.json`, and `data/melodies/*.json`.

**Algorithm — reachability fixpoint.** Start from `start.room`; maintain a set of
reachable rooms and a set of collected note ids (all notes in reachable rooms). A
door-gated exit becomes passable once **every note in its melody is among the
collected notes**. Repeat — expand reachable rooms across passable exits, add their
notes — until nothing changes.

**Assertions (non-zero exit on any failure):**
1. **Reachability.** Every room, and every gated door, is eventually
   reachable/openable from the start.
2. **The length ramp (§3.6).** For every door, its melody length is ≤ the number
   of notes collectable *before* that door first becomes openable.

   **The ramp is a ceiling, not an equality — and the ceiling must be tight.** The
   design doc's table (1→1, 2→2, 3→3, 4→3, 5→4, 6→5) reads as a prescription; this
   validator enforces it as an upper bound, which is the workable formalization
   since exact matching would forbid a deliberately easy late door. But a loose
   ceiling silently defeats the anti-brute-force argument the ramp exists for: a
   two-note door with five notes held passes this check at 25 sequences, which is
   guessable. **The validator therefore also warns** (non-fatal) when a door's
   length is more than one below the ramp figure for the notes available, so a
   too-easy door is visible rather than silent. See D-M3-8 for the concrete case
   this caught.
3. **Referential integrity.** Every exit's `to`/`to_entry` exists; every `door`
   melody id exists; every melody note resolves to a known pitch class; every
   `notes` entry is a known note id.

**No pitch, melody, or musical pattern is hardcoded in the validator** — it reads
notes and melodies from data exactly as the game does (the §3 one rule applies to
Python here too, in spirit: the validator asserts *shape*, not specific tunes).

**CI:** `.github/workflows/validate.yml` runs the validator on push/PR. The Godot
unit tests continue to run **locally** (`godot --headless --script`), matching the
repo's existing pattern — booting Godot in CI is out of scope for M3.

---

## 8. End-to-end flow (assembled)

```
World._ready → RoomGraph.start() → enter_room("room_a", "spawn")
  → Room A paints its TileMapLayer, drops n_step pickup, D2 + D1 doors, two chimes
  → player placed at "spawn"; camera limits = Room A bounds (fixed screen)
Collect n_step (space) → NoteInventory gains E → note bar shows a movement swatch
Strike D2's chime (space) → hears/sees [E]
Press space at D2 → instrument state → play E → MelodyLock MATCH → D2 opens (body off)
Walk through the gap → RoomLink fires → enter_room("room_b", "from_a")
  → collect n_mend (D); walk east → RoomLink → enter_room("room_c", "from_b")
  → collect n_break (C)  [player now holds C, D, E]
Walk back C → B → A (free gaps)
Strike D1's chime → hears/sees [C, D, E]
Press space at D1 → instrument state → play C, D, E in order → MATCH → D1 opens
Walk through north gap → RoomLink → enter_room("room_d", "from_a")   ← the payoff
```

Throughout: notes still sound and still ring in both overworld and instrument
state (`Synth`/`NoteVisuals` never gate on `effects_enabled()`); only gameplay
effects are suppressed in the instrument state, exactly as in M2.

---

## 9. Test plan

Same split as the repo's pattern: the **pure seam is unit-tested**; autoload/scene
glue is verified by running the game; the **graph is validated headlessly in
Python**.

- **Python validator (`scripts/validate_rooms.py`, in CI):** reachability, the
  length ramp, and referential integrity over the real data files (§7). This is the
  automated proof that the backtrack is *checkable rather than hoped-for* (§7.5).
- **Unit (pure GDScript, `godot --headless --script`):** the existing 32 assertions
  stay green. If any non-trivial pure helper is extracted (e.g. tile-grid → bounds,
  or an entry-position calc worth pinning), add a case; otherwise M3's new code is
  impure autoload/scene glue and is run-verified, not unit-tested. Do not fabricate
  unit coverage for glue.
- **Persistence check (run-verified, and the one most likely to be missed):** open
  D2, take `n_step`, leave Room A, return. The door must still be open and the
  pickup must still be gone. This is the case a naive `enter_room` re-instance
  breaks, and backtracking is the milestone.
- **Run verification (owner):** each step's done-condition (§10) checked by running
  `godot .` and watching the described behaviour. Report these as run-verified,
  never as "tests pass," for anything visual or runtime — the one honest source of
  truth for feel, camera, transitions, and the chime.

Every change begins with `godot --headless --import` (parse check), ends with the
unit run green, the §3 one-rule guard clean, and `validate_rooms.py` exiting 0.

---

## 10. Step ladder — build order and done-conditions

Build one step at a time, stopping after each so the owner can run it.

- **Step 0 — Delete the scaffolding, add the gray `TileSet`.**
  Remove `main.gd`'s procedural `_spawn_*`; stand up `world.gd`/`world.tscn` as the
  persistent host with the player/UI/overlay but a single hardcoded room still, to
  keep the game runnable. Owner creates the two-tile gray `TileSet` (§6.7).
  **Done when:** the game still boots and plays exactly as M2 did, now hosted by
  `World`, with the `TileSet` present.
- **Step 1 — Rooms from data + the graph + the camera clamp.**
  `RoomGraph` and `WorldState` autoloads + `data/rooms.json` + per-room geometry;
  `Room` builds its `TileMapLayer` from data; `World.enter_room` places the player
  and sets camera limits. `test_room.gd/.tscn` deleted.
  **Done when:** the four rooms exist as gray boxes, the start room loads, the
  camera clamps to bounds (no void), and the §5.3 consistency check passes at boot.
- **Step 2 — Transitions.**
  `RoomLink` in every free gap; walking through moves the player to the target
  room's named entry with no bounce-back.
  **Done when:** the player can walk A↔B↔C through free gaps, arriving at the right
  entry each time, camera re-clamping per room, **and a note taken in a room is
  still gone after leaving and returning** (§6.3a).
- **Step 3 — Doors gate real exits.**
  Place D2 (`door_tutorial`) and D1 (`door_backtrack`); their blocking bodies sit in
  front of the A→B and A→D links; opening disables the body; gems tint by category
  (D-M3-3).
  **Done when:** D2 opens with `[E]`, **stays open after leaving Room A and coming
  back** (§6.3a), and then Room B is reachable; D1 refuses until
  the player holds C and D, then opens with `[C, D, E]` and Room D is reachable; gems show
  category + progress, not the specific notes.
- **Step 4 — Clue delivery (the chime).**
  `MelodyChime` beside each door, playing the door's melody with colour pulses;
  re-strikeable. This is the moment M2's scaffolding is fully retired — content
  lives on the chime, structure on the door.
  **Done when:** striking a door's chime plays and shows its melody, and a player
  can learn a door's tune from the world rather than from the gems.
- **Step 5 — The validator, CI, and the gate.**
  `validate_rooms.py` + `.github/workflows/validate.yml`. Then the milestone check:
  a fresh player completes the slice in 5–10 minutes and gets the loop unprompted.
  Write `docs/m3-progress.md`; update `CLAUDE.md` §2/§8 and `README.md` in the same
  change (§12 of `CLAUDE.md`).
  **Done when:** the validator passes in CI and the play-through gate (§11) is met
  and recorded.

---

## 11. Verification of the gate

M3 is complete when, from a clean launch, an unfamiliar player — with no
explanation — collects the notes, learns and opens the tutorial door, explores to
the deep room, realizes the far note opens the door they passed at the start,
backtracks, and opens it, **in 5–10 minutes**, and can articulate the loop
afterward; and `scripts/validate_rooms.py` passes in CI proving the graph is
solvable and the length ramp holds. That play-through, written up in
`docs/m3-progress.md`, is the milestone — and the project's decision point (design
doc §11).

---

## 12. Decisions recorded

Design/architecture calls made while specifying M3, kept here so a fresh session
inherits the reasoning (ADR-style; the repo has no `docs/decisions/`).

- **D-M3-1 — Room geometry lives in data (Fork B), not editor-painted scenes.**
  Each room's gray-box grid is a per-room JSON file that a `Room` script paints onto
  a `TileMapLayer` using a shared gray `TileSet`. Chosen so the whole slice is
  buildable and **headlessly verifiable** without blocking on in-editor tile
  painting, and so geometry is diffable and reviewable — which also matches the
  validator ethos of keeping the layout in data (§7.5). It still meets the design
  doc's real requirement: a `TileMapLayer` with **collision from the tileset**, not
  procedural `StaticBody2D`s. The literal "scenes with a `TileMapLayer`" wording is
  satisfied in mechanism; the editor's visual painter and real tilesets move to M5
  with the art pass. **Alternative (Fork A):** editor-painted room `.tscn`s with
  `Marker2D`/`RoomLink`/`Door`/`Chime` placed by hand — everything else in this spec
  is unchanged. The owner may take A at spec review; only §5.2, §6.3, and this entry
  change.
- **D-M3-2 — Clue delivery is the re-strikeable chime; the other three vectors are
  deferred.** The owner's call (design doc Q5, §9): for the demo, only the chime
  object is built — struck with `space`, it plays the door's melody and pulses its
  colours, and is re-strikeable so no journal is needed. The **mural (colour
  sequence)**, **humming creature/NPC**, and **cross-room fragment** vectors are
  endorsed as good ideas and explicitly deferred, not rejected; they remain logged
  as candidates in design doc §3.6.
- **D-M3-3 — Door gems show category (structure), not the note's exact colour
  (content).** M2's gems tinted by category **+ index**, which reveals *which* note
  — flagged in M2 as scaffolding (M2 D3) to be removed at M3. With clue delivery now
  in the world, gems drop to the category's representative hue: count, progress, and
  categories involved are shown (structure the design doc §3.6 wants), the specific
  notes are not (content, now on the chime). This retires the M2 scaffolding as
  planned.
- **D-M3-4 — Doors gate a gap; they never teleport (design doc §3.7).** Opening a
  door disables its blocking body so the `RoomLink` behind it becomes reachable;
  walking through is a separate beat. Reason: if opening a door moved the player, a
  door would *be* a transition, and every gated boundary would read as a puzzle —
  the §4.5 failure the door/transition split exists to prevent.
- **D-M3-5 — The camera is a follow-cam clamped to room bounds, set per room in
  `World.enter_room` (design doc §3.7).** A room at or just above the viewport in
  both dimensions clamps to a fixed screen — **20×12 tiles at 16px**, or 16×9 at
  20px; never 20×11, which falls four pixels short vertically (§5.2). Larger rooms
  scroll. This removes the out-of-bounds void and makes
  room size a design dial rather than an architectural commitment — no per-screen
  camera mode. 320×180 is never hardcoded outside project settings (keeps the parked
  zoom option, §3.7, alive).
- **D-M3-6 — `rooms.json` is graph-only; geometry is separate.** The graph the
  validator reads (exits, entries, note contents, gates) is kept apart from the
  spatial data (tile grid, positions), so validation data and rendering data do not
  entangle. A boot-time consistency check (§5.3) plus the CI validator keep the two
  from drifting.
- **D-M3-8 — D1 wants three notes, not two.** With `[C, E]`, Room B's `n_mend` (D)
  opens nothing anywhere in the slice — a collectible that does nothing, in a slice
  whose gate is "understands the loop" — and D1 is 3² = 9 ordered sequences, which a
  mashing player opens in under a minute, skipping the chime and the backtrack
  realization. The gate would then fail *silently*: finished in time, loop never
  learned. `[C, D, E]` makes every collected note load-bearing, raises the space to
  27, and matches the design doc's ramp figure exactly rather than sitting under its
  ceiling.
- **D-M3-9 — Room contents persist in `WorldState`, keyed by id.** Rooms are freed
  and re-instanced on transition, so opened doors and taken pickups must be recorded
  outside the room or the slice's required return to Room A shows a locked door and
  an uncollected note. Keyed by id rather than node path or position, so moving
  something in the geometry data doesn't lose its state. In-memory only — this is
  about surviving a transition, not a relaunch; saves are not in M3 scope.
- **D-M3-7 — CI runs the Python validator only; Godot tests stay local.** The
  validator is pure Python and cheap to run in CI (§7.4). Booting Godot in CI is out
  of scope for M3; the unit suite continues to run locally per the repo's pattern.

---

## 13. Open questions — do not decide these (from §9 of `CLAUDE.md`)

Implement nothing that assumes an answer; ask if a task seems to need one.

- **Which pitch classes map to which category** — a musician's decision. M3 reuses
  the three M2 placeholders; do not fill in all twelve.
- **What each note actually does in the world** — categories stay data in M3; no
  ability behaviour attaches. The backtrack is a **melody-door note-gate** (you
  cannot play a note you do not own), *not* an ability gate — chosen precisely so no
  note behaviour is built before M5.
- **Combat / bosses** — whether they exist, and which approach. Not M3.
- **The convergent finale** — every door melody is meant to be a fragment of one
  larger piece, but code must never assume this. `key`/`mode`/`finale_role` stay
  read-by-nothing.
- **The other clue-delivery vectors** (mural, humming creature, cross-room
  fragment) and a **melody journal** — endorsed and deferred (D-M3-2); do not build
  them in M3.
- **A map, camera zoom, the HUD resize** — parked (design doc §3.7, Q23/Q25/Q26).
