# Room authoring recipe

How a new room gets built, from empty bounds to a frozen, verified, composed room. Written
from authoring the Gallery (`room_b`) in M6; it is the durable half of that milestone — the
process the nine remaining M7 rooms follow so their layout stops being nine sets of by-eye
checks and hand-derived numbers.

**CLAUDE.md is authoritative** for the *why* and the exact schema (§4 architecture, §5 data
formats, §6 design constraints). This file is the *how* — the order of operations and the
tools. Where they disagree, CLAUDE.md wins.

---

## The two schemas

A room lives in two files, referenced by id (the same pattern as the note registry):

- `data/rooms.json` — the **graph**: which rooms exist and how they connect. `validate_rooms.py`
  reasons about this (reachability, the door length ramp). It never boots the engine.
- `data/rooms/<id>.json` — one room's **geometry and content**: `size_tiles`, `grid`, `entries`,
  `links`, `pickups`, `chimes`, `sealed_doors`, `props`. `lint_rooms.py` and `seal_test.py` read
  this. `RoomGeometry` (game) and `roomlib.py` (tools) share the placement maths so door
  footprints, openings and landings are **derived, never hand-kept**.

A room's `.tscn` is not edited to change layout — geometry is data-driven. `room.gd` paints the
grid and `RoomContent` instances the content from the JSON.

---

## The passes, in order (each a gate)

The build order is a gate, exactly as the milestone ladder splits a room by fidelity pass. Do
them in order; freeze the shape before anything downstream assumes it.

1. **Geometry** — carve the grid. Lint green, preview by eye, **owner signs off the shape, then
   it is FROZEN.** Everything after assumes frozen geometry.
2. **Content and wiring** — pickups, chimes, doors, sealed doors, placed on valid floor outside
   the reserved zones. Validator, seal test and boot check green. Owner walks the room and its
   neighbours.
3. **Light** — under M5's ruling (§2): no static lights; every object emits its own glow; doors
   are the beacons. A room with no doors/chimes may cost ≈ nothing here — **that is a finding,
   record it**, don't invent a light source to fill the dark (new vocabulary is a stop-and-ask).
4. **Detail** — rubble props only, under a per-room cap the owner sets. Cracks/finer detail are
   deferred to M9.
5. **Capture + verify** — silhouette test, capture the reference still, all checks green.

Geometry and detail are what a new room actually costs to author; light is often near-zero;
content scales with doors/links/objects.

---

## Authoring the grid (the geometry pass)

**Author subtractively.** Start as solid rock (`#`) in the `size_tiles` bounds and carve the
walkable space (`.`). Natural rooms are irregular and asymmetric — a shape, not a rectangle.

Grid characters (the only three; anything else is a lint error):

| char | meaning |
|---|---|
| `#` | rock — wall, collision, light occluder |
| `.` | floor — walkable |
| `o` | interior outcrop — **rock** for terrain and collision, counted apart for the rock budget |

Rules the lint enforces or reports, all from doing this by hand before the tool existed:

- **Rock budget 20–30%** of the bounds, excluding outcrops (a warning, not an error). Long thin
  rooms run naturally high — a 96×18 room is ~22% wall before any carving, so the Gallery sits
  at 30.5% by design and the threshold was **not** moved. Leave rock the player never reaches.
- **Openings are 2 tiles wide.** A link/sealed-door `at` cell plus its neighbour along the edge
  must both be floor.
- **Every exit gets a straight apron** — a flat run of at least `APRON_MIN` (4) floor tiles
  straight in from the opening. No steps or rock in the approach.
- **Transitions are edge-band, mirrored.** An exit is a thin band at the room boundary; the
  matching `from_<room>` entry on the far side lands one tile inside the destination's mirrored
  edge, at the **same height**, so leaving one room's right edge arrives at the next room's left
  at the same row. A single-tile opening or a point entry breaks the mirror.
- **`size_tiles` must equal `[cols, rows]`** and every row must be that wide (no ragged rows).

**Door placement is derived, not authored.** A door sits at its link cell plus `DOOR_INSET`
(1.5 tiles) inward, centred across the 2-tile opening, facing the room. A player arriving
through a doored link lands `DOOR_ENTRY_INSET` (3.5) in; a plain link lands `ENTRY_INSET` (1)
in. The door's footprint, its approach clearance and any stub corridor must hold **no content**.
Don't compute these by hand — the lint derives them and fails if content intrudes.

**Content coordinates are absolute tile cells** and do **not** move when a room is resized. After
any geometry change, re-check every pickup/chime/prop cell (the lint does this too).

---

## Content and props

Each is a small array of `{ "at": [col, row], … }` in the room file, placed on floor:

- `pickups` — `{ "note_id", "at" }`. A collectible note (by pitch class).
- `chimes` — `{ "melody_id", "at" }`. A door's melody clue; place it **beside its door**.
- `sealed_doors` — `{ "at", "sockets" }`. Decorative unopenable door at a perimeter opening
  (the five-note exit); placed and reserved exactly like a real door.
- `props` — `{ "at" }`. Rubble piles. **No collision, no light, no interaction**, so they never
  touch the frozen geometry, the validator or the seal test. Deterministic `Prop` shape per
  cell. Keep them off the aprons, out of door footprints, and clear of outcrops. Cap per room is
  the owner's call (the Cistern used ≤5; the Gallery ≤6, 5 placed).

---

## The light and detail passes

- **Light:** place nothing unless the room has objects that emit. The room reads by its doors
  (beacons), its chimes, its pickup and the player's travelling light. If that leaves stretches
  dark, that is the intended contrast between lit hubs and dim traversal — record it as a
  finding; do not add a static light or a new object type to brighten it.
- **Detail:** rubble only, seated at wall/outcrop bases, spread so each screen has some floor
  texture, under the cap. Provisional art — it will be redone in later passes; don't gold-plate.
- **Silhouette test:** render the composed room black-on-white and confirm each object type is
  identifiable by shape alone (pickup = diamond, chime = struck bar, door, rubble = low lumpy
  mass, player). Adding only already-distinct object *types* to a new room keeps this trivially
  true; a genuinely new type must be checked.

---

## The toolchain — run after every room change

```
godot --headless --import                       # parse check, first
python3 scripts/validate_rooms.py               # graph: reachability + door length ramp
python3 scripts/seal_test.py                    # each door closed seals its edge trigger
python3 scripts/lint_rooms.py [room_id …]       # per-room geometry checks (below)
```

Plus the whole test suite (`tests/test_*.gd`, 104) and the one-rule grep from CLAUDE.md §3
(no pitch literal in any gameplay `.gd`) before freezing or committing.

`lint_rooms.py` turns the by-eye checks into machine checks. **Errors** (non-zero exit) are
structural — the room would not work: grid integrity, non-perimeter or non-floor openings,
content off floor / out of bounds, a `from_*` landing on rock, content inside a door's derived
footprint/approach. **Warnings** (zero exit) are convention and quality: a blocked apron, rock %
off target. Legacy grey-box rooms (`room_c`, `room_d`) trip warnings on purpose until M7
rebuilds them. Green — no errors — is the bar before a shape is frozen.

The door/opening/landing maths lives once, in `roomlib.py` (the Python mirror of
`RoomGeometry`); `seal_test.py` and `lint_rooms.py` both import it. Keep its constants in step
with `room_geometry.gd` / `door.gd` / `player.tscn`.

---

## Capturing the reference still

The still is the M5-bar record: **internal resolution (960×540), no vignette** — the
`GameViewport` content before the Display's post-process. Headless renders blank, so capture
**windowed**.

There is no permanent capture key in the shipped input path (debug keys are removed on close).
Capture with a **throwaway scene** run windowed and deleted after: instance `main.tscn`, reach
`GameViewport/World`, `enter_room(<id>, <entry>)`, hide the `UI` CanvasLayer, then read
`GameViewport.get_texture().get_image()` and `save_png`. For a room wider than one screen,
reposition the player per screen (its follow-cam clamps to the room) and stitch the 960×540
frames into a full-room composite. A full-bright companion (set the world `CanvasModulate` to
white) makes the layout legible when the as-played room is deliberately dim.

Save under `docs/<milestone>-reference/`. Godot rewrites `project.godot` on a windowed run
(it drops default-valued keys) — revert that churn before committing.

---

## The freeze gate

A room's geometry is frozen only after: lint green, the shape looks right, and **the owner
signs off on `godot .`**. After that, any edit must preserve the openings, door footprints,
approach clearances, aprons, mirrored entries and the rock budget — re-verify all of it. The
Cistern (`room_a`) and the Gallery (`room_b`) are both LOCKED under this gate.
