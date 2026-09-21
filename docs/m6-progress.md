# M6 progress — authoring pipeline and room two

**Status:** in progress. Started 2026-09-20.
**Spec:** `docs/m6-spec.md` (measurement half superseded — see the re-scope below).

---

## Re-scope (owner, 2026-09-20)

M6 as written did two things: **build an authoring pipeline + room two**, and **measure
hours-per-room to project the schedule**. The owner has **no deadline** and will spend
whatever time the game needs, so the projection has nothing to inform. **The measurement
half is dropped.** The making half stands — its value is nine fewer rooms of by-eye checks
and hand-derived numbers (the design doc's named volume risk), which doesn't depend on a
schedule.

**Revised gate:** the Gallery is authored to the M5 quality bar (owner's judgment, its still
beside `docs/m5-reference/cistern-final.png`), **and** the authoring pipeline that made it
cheaper exists. No hours number, no projection, no pre-registered ceiling.

**What changes from the spec:**
- **Dropped:** §1 (the measured gate), §4 Step 0b/0c numeric rulings (weekly hours, ceiling,
  stop-loss), §5's minutes-per-occurrence and saving-×-9 columns, §10's number/coverage
  statement, §11 (the projection). `2–3 hrs/room` from the owner is a loose expectation, not
  a ceiling anyone enforces.
- **Kept:** §2 (the Gallery, replacing `room_b`), §3 (non-goals), §5's *enumeration* of
  today's authoring pain (it still decides which tools are worth building — just judged by
  "does this kill a hand-error-prone step?", not by hours saved), §6 (the pipeline), §7–§9
  (build the Gallery), §12–§13.
- **Tools are judged, not measured.** Build a tool only when it removes a concrete by-eye or
  hand-derived step, or real toil; prefer the smallest thing that works; stop tooling when the
  Gallery is smooth to author. No gold-plating for rooms not yet in front of us (CLAUDE.md §11).

**Confirmed rulings**
1. Room two = **the Gallery, replacing `room_b`** (96×18, 3-screen horizontal shelf).
2. **`scripts/tlog.py` stays as an optional gut-check** — the owner may time a step out of
   curiosity, but nothing requires it and no step waits on it.

---

## Step 0a — Time log (built 2026-09-20, now optional)

`scripts/tlog.py` (stdlib) + `docs/m6-time-log.csv` are built and smoke-tested
(`start`/`stop`/`note`/`report`, owner vs CC time reported apart). Retained as an optional
tool; not load-bearing under the re-scope.

---

## Step 2 — The pipeline (order)

Dependency-first, each the smallest thing that removes a real step:

- **2a. Split `room.gd`** — **DONE 2026-09-20.** `room.gd` 299 → **164 lines**. Extracted two
  seams: `scripts/room/room_geometry.gd` (`RoomGeometry`, pure — inset constants + cell/inward/
  opening/edge-band maths + a consolidating `inset_point()`; **16 unit tests**) and
  `scenes/rooms/room_content.gd` (`RoomContent`, the props/pickups/chimes/sealed-doors/door
  instancers). Behaviour-preserving; numbers unchanged, so the Cistern's locked geometry holds.
  Verified: parse clean, **104 tests** pass (was 88), `validate_rooms` + `seal_test` green,
  one-rule grep clean. **Owner visual check pending** (spec §6 2a): `godot .`, the Cistern
  renders identically.
- **2b. Room lint** — **DONE 2026-09-20.** `scripts/lint_rooms.py` turns the by-eye checks into
  machine checks: grid integrity, 2-tile perimeter openings, content on floor / in bounds,
  `from_*` landings, **door footprints + approach clearance** (derived, not hand-kept), exit
  aprons and rock % (warnings). Errors fail; convention/quality warn (legacy grey-box b/c/d warn
  on rock %, `room_a` is error-clean at 29.9%). Backed by `scripts/roomlib.py` — the Python
  mirror of `RoomGeometry`, now the single source for the placement maths — onto which
  `seal_test.py` was **refactored** (its hand-kept copy of the door/edge maths removed; still
  passes identically). Fixture test `scripts/test_lint_rooms.py`: **12 checks**, one per rule.
- **2c. Room preview** (annotated render of a room file, SVG if Pillow absent).
- **2d. Room scaffold** (`new_room.py`): valid solid-rock skeleton, registered, lint-green.
- **2e. Generalise `seal_test.py`** to any room by id.
- **2f. Dev jump-to-room** — only if walking to the room dominates review time.
- **2g. `docs/room-authoring.md`** — written from doing room two, finalised at the end.

Each of 2b–2f is built only if 2a-era recon shows it removes a concrete step; otherwise skip.

---

## Step 3 — Gallery geometry (room two, Parts 2–3)

**Built and FROZEN 2026-09-21.** Owner signed off the shape on `godot .`; geometry is now LOCKED
(same status as the Cistern). Part 3: content already valid (pickup `n_mend` `[16,8]`, unmoved);
no doors, so the seal test is N/A; final verify re-run green before freezing.
Hours (owner): _pending your log._

**Gallery geometry is LOCKED — any future edit must preserve:** the 96×18 bounds; the W opening
(link `[0,13]`, rows 13–14) mirroring the Cistern's locked door; the S opening (link `[84,17]`,
cols 84–85 rows 13–17); `from_a` `[1,13]` and `from_c` `[84,16]`; the 4-tile W apron and 5-tile
S apron kept clear; and rock ~30.5%. Light and detail (Step 5) are a separate task and add no
geometry.

Transcribed **revision 2** of `docs/m6-reference/gallery-mask.txt` into `data/rooms/room_b.json`
— the Gallery replaces `room_b`, keeping its id, entry names and outgoing links. Graph
`rooms.json` unchanged; **no `.tscn` edited** (geometry is data-driven).

Facts:
- **Size** 96×18 (2880×540 px = 3×1 screens); scrolls horizontally only.
- **Rock** 30.5% excl outcrops / 32.6% incl (floor 1165, rock 527, outcrop 36). Over the 20–30%
  band and **left as-is by design**: a 96×18 room is ~22% wall before any carving (two 2-row
  long walls + end walls), so ~31% is near the floor for this shape. Lint emits the rock warning
  as expected; the threshold was **not** changed. (The mask's prose header says 30.6% / rock 528
  — one cell stale vs the rev-2 grid's 30.5% / 527; the grid is authoritative and matches the
  owner's 30.5%.)
- **W exit** → `room_a` (Cistern): link `[0,13]`, opening rows 13–14, **4-tile apron**; `from_a`
  = `[1,13]` (computed landing `[1,14]`, floor). At rows 13–14 per ruling **A2**, height-mirroring
  the Cistern's locked east door `door_tutorial` (rows 13–14).
- **S exit** (provisional) → `room_c`: link `[84,17]`, opening cols 84–85 rows 13–17, **5-tile
  apron**; `from_c` = `[84,16]` (opening's first cell; computed landing `[85,16]`, floor).
- **Content** pickup `n_mend` stays `[16,8]` (floor, outside both keep-clear aprons). No chimes,
  no doors.
- **Narrowest passage** ~3 rows near cols 52–53 (above the outcrop), per the mask.

**Known placeholder:** the S opening is wired to `room_c` (`to_entry from_b`) only to keep
`room_b`'s existing outgoing link. Geometrically S(`room_b`)↔W(`room_c`) is **not mirror-aligned**;
the mask says S really leads to the Drip chamber. **M7 rewires S→Drip** — do not treat the current
S↔`room_c` pairing as final.

**Conflicts resolved (Part 1 → owner rulings):** A (W height vs locked Cistern door) → **A2**,
mirror at rows 13–14. B (second exit E→S) → **approved placeholder** wired to `room_c`, `from_c`
at the opening's first cell. C (rock % over band) → **expected**, reported not fixed.

**Verify (all green):** import clean · 104 tests · `validate_rooms` OK · `seal_test` OK ·
`lint_rooms room_b` no errors (rock warning only) · one-rule grep clean · `RoomGraph` boot check
passes (graph↔geometry links/entries mirror). **Owner still to confirm on `godot .`:** the shape
at the M5 bar, and **vertical camera jitter at the top/bottom edges** (first exactly-one-screen-tall
room). Geometry is frozen only after that sign-off (Part 3).

## Step 5 — Light and detail (2026-09-21)

Owner rulings for this room (§13.6, §13.7): **dim traversal shelf**, **rubble cap ≤6**, and a
**one-off throwaway capture script** (no F2 key re-added to the shipped input path).

**Light — the finding the spec predicted (§9).** The Gallery has no doors and no chimes, so
under M5's ruling (no static lights; every object emits its own glow; doors are the beacons)
it has **nothing to place** in the light pass — its only emitters across three screens are the
`n_mend` pickup (left third) and the player's travelling light. Cost ≈ zero, as §9 anticipated.
The consequence is real and **owner-accepted**: the Gallery is intentionally the **dim shelf**
between lit hubs, a pacing contrast to the Cistern. This was the §9 stop-and-ask (a doorless
room can't be given a beacon without inventing vocabulary, which §2.5 forbids) — resolved as
"accept the dim read," not "add a light." If M7 later puts a real door on this room, it brings
its own beacon then.

**Detail — rubble.** Added a `props` array to `data/rooms/room_b.json`: **5 rubble piles**
(cap ≤6) at `[9,12] [26,6] [45,12] [66,8] [88,6]`, ~1–2 per screen, all on floor and clear of
the W apron, the S apron, the outcrops and the pickup. Deterministic `Prop` shapes (no
collision/light), so the frozen geometry, validator and seal test are untouched. Cracks/finer
detail stay deferred to M9 (spec default). `lint_rooms room_b` confirms every prop cell is
on-floor and unreserved.

**Silhouette test — passes by construction.** The Gallery's only objects are the pickup
(bright diamond) and rubble (low dark lumps), an already-established-distinct pair (D-M4-7;
`prop.gd`'s documented pass), plus the player. No new object type was introduced, so
black-on-white distinguishability is unchanged from M5.

**Reference stills** captured at internal res (960×540, no vignette — same nature as
`cistern-final.png`), stitched into 2880×540 three-screen composites via a throwaway
`_capture_gallery.tscn` (deleted after use; capture must run windowed, headless renders blank):
- `docs/m6-reference/gallery-final.png` — the as-played dim view (the quality-bar still).
- `docs/m6-reference/gallery-lit.png` — a full-bright companion so the layout/rubble read
  without the darkness.

**Verify (all green):** import · 104 tests · 12 lint fixtures · `validate_rooms` ·
`seal_test` · `lint_rooms room_b` (rock warning only) · one-rule grep clean.

**Owner gate still open (§1/§10):** the M5-bar judgment of the Gallery beside
`cistern-final.png`, made live on `godot .`. Step 5 is complete pending that sign-off.

## Progress log

- **2026-09-20** — Step 0a built (tlog). M6 re-scoped: measurement dropped, pipeline + Gallery
  kept. Room two confirmed = Gallery.
- **2026-09-20** — 2a done: `room.gd` split → `RoomGeometry` (pure, 16 tests) + `RoomContent`,
  299→164 lines. CLAUDE.md/README brought in line with the re-scope + split.
- **2026-09-20** — 2b done: `lint_rooms.py` + `roomlib.py`; `seal_test.py` refactored onto
  `roomlib`; `test_lint_rooms.py` (12).
- **2026-09-21** — Gallery geometry (Part 2) built from the rev-2 mask into `room_b` (96×18);
  W→room_a mirrored to rows 13–14 (A2), S→room_c placeholder; verify green.
- **2026-09-21** — owner signed off the shape; Part 3 done — geometry **FROZEN/LOCKED**, content
  unmoved, no doors (seal test N/A), verify re-run green. Next Gallery step is light + detail
  (Step 5), a separate owner-directed task.
- **2026-09-21** — Step 5 done (pending owner sign-off): light pass is a no-op (dim traversal
  shelf, the §9 finding, owner-accepted); 5 rubble props added (cap ≤6); silhouette passes;
  `gallery-final.png` + `gallery-lit.png` captured. Verify green. Gate: owner judges on `godot .`.
