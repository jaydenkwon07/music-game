# M5 — The cave look · Progress

**Status: IN PROGRESS.** Steps 0–4 built and verified; Steps 5 (compose the
Cistern) and 6 (run the §1 gate, record) still open — the store-page gate inherited
from M4 is **not yet met**.
**Spec:** `docs/m5-spec.md`. **Gate:** §1 — *a still of the finished room is
something you would put on a store page* (owner's judgment on `godot .`, not a
headless check).

Verification commands that must stay green (re-run every step):

```
godot --headless --import
godot --headless --script tests/test_melody_matcher.gd          # 32
godot --headless --script tests/test_instrument_keyboard_layout.gd  # 21
godot --headless --script tests/test_rock_bevel.gd             # 23
godot --headless --script tests/test_door_layout.gd            # 12  (88 total)
python3 scripts/validate_rooms.py
python3 scripts/seal_test.py
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'
```

All green as of Step 5b (2026-09-20).

---

## Step 0 — Loose ends

- **0a (1440p scaling):** the `Display` now scales in **two stages** — a `Prescale`
  SubViewport nearest-upscales the 960×540 buffer to the largest integer multiple
  that fits the window, then the `Display` bilinear-resamples that to the window.
  1440p (a ×2.67 target) no longer shimmers or letterboxes 44% of the screen;
  1080p/4K stay exact. `scenes/main.gd` + `scenes/main.tscn`.
- **0b/0c/0d:** already landed in `CLAUDE.md` by the owner (M3 waiver, re-planned §8
  ladder, §5/§6 staleness). Also corrected four *code* comments that still named an
  old internal resolution (640×360 / 320×180) as current — comment-only, no
  behaviour change; the snapping they describe is whole-pixel and resolution-agnostic.

## Step 1 — Tileset architecture

Rock became a Godot 4 **47-tile blob terrain** ("match corners and sides").
`rock_tileset.gd` builds the terrain set with per-tile peering bits; `room.gd`
dropped its hand-rolled 16-tile mask and calls `set_cells_terrain_connect`, padding
a one-cell rock ring outside the grid so the outer perimeter reads solid (off-camera,
behind the wall). Floor stays a spatial-hash variant, not terrain. Verified: 47
unique configs, **zero holes** terrain-connecting a diagonal blob and all four rooms.

## Step 2 — Draw the rock (procedural first pass)

**Owner decision (2026-09-19): keep `rock_tileset.gd` generating, not loading a
PNG** — a deviation from the spec's letter, chosen so `palette.json` still retints
the whole cave (a baked PNG would freeze it) and so we could iterate via
screenshots. If a hand-drawn PNG is wanted later, only `_build_atlas` changes; the
47 tiles, bits, collision and layout stay put.

The drawing is now a flat `rock_mid` body with subtle same-neighbour facets and a
**distance-field contact band** darkening toward `rock_void` as a pixel nears floor
— uniform on every exposed side, so convex corners read rounded and concave ones
fill with **no per-corner case and no carved silhouette** (two earlier crude
treatments — a half-tile chamfer, then a `rock_void` inner notch — read as
octagons / chipped rock and were removed). Floor got subtle grit on a `rock_shadow`
base. Tile art is deliberately hard to judge until it has real lighting to sit in;
the owner chose to **proceed and revisit tile contrast under Step 3/5 lighting**
rather than tune it in the dark.

## Step 3 — Light falloff and post-processing

- **3a — banded falloff:** the shared light gradient uses **CONSTANT
  interpolation** with `Lighting.band_count` hard steps so the fade reads as rings
  of the ramp, not a blur. Owner tuned **4 → 5** for a gentler step.
- **3b — vignette:** a post-process shader (`scenes/fx/vignette.gdshader`) on the
  `Display`, applied **after** the upscale (output resolution). **Bloom stays off**
  (spec §12) — a world on an emptiness-to-fullness arc shouldn't glow more.
- **3c — interior masses:** already satisfied. Interior `#` cells render as rock via
  the terrain, lit by the same lights; the only dark rectangles are doors (Step 5).
  No code needed.

## Step 4 — Carve the Cistern

`room_a`'s geometry was **replaced by the Cistern mask** (48×36, 30px tiles =
1440×1080 = 1.5×2 screens — the first **scrolling** room; the camera clamp already
supports it). Geometry only — no art, no door frames/gems/brass, no light changes.

- **Grid** transcribed directly from `docs/m5-reference/cistern-mask.txt` (floor
  1177, rock 517, outcrop 34 = 29.9% solid rock). `room.gd` now treats **`'o'`
  (outcrop) as rock** for terrain + collision (the one code change). Collision is the
  30px grid exactly; the bevelled/overhanging silhouette is left to the terrain
  tiles, not reproduced in data. Terrain resolves the new geometry with **zero holes**.
- **Exits kept pointing where they pointed:** the mask aligns N (3 gems) = north =
  `door_backtrack` → room_d and E (1 gem) = east = `door_tutorial` → room_b, matching
  room_a's existing edges and gem counts. Only the position along each edge moved
  (N col 16→23-24; E row 8→13-14). Neighbours (`room_b`, `room_d`) were **not
  touched** — a `from_*` entry lands from the destination room's own link geometry,
  not the source corridor's position. Links re-pointed to `at [23,0]` (N) and
  `at [47,13]` (E); `from_b`/`from_d` anchors moved to the new corridors.
- **W and S corridors are geometry-only stubs** (owner-confirmed): floor to the
  boundary, no links, no `rooms.json` entries. They dead-end at the Step-1 ring-pad
  wall (off-camera), so no fall-through and no transition. W becomes a real exit
  later; S gets the five-gem door in Step 5. Both stubs kept free of content.
- **Content kept in place** (owner ruling c): spawn `[10,10]`, pickup `n_break`
  `[6,12]`, chimes `door_tutorial [22,12]` and `door_backtrack [10,6]` were all
  already valid floor outside the reserved zones and reachable, so **none moved** —
  preserving the M4 cold-open beat (dark start, a distant light draws you). No
  relocation was needed.
- **Reserved zones kept clear:** door footprints (N cols 22-25 r1-2, E cols 45-46
  r12-15, S cols 32-35 r33-34), 2-tile approach clearances, and the W/S stubs hold
  no content.

**Door seal (condition on owner ruling a-i), empirically confirmed.** `DOOR_INSET`
and `room.gd` were left unchanged, so the placeholder doors sit at **N row 4 / E
col 43** — *inside the approach-clearance band*, one tile past the mask's reserved
footprint. A flood-fill using the real door-blocker geometry (`72×90` slab centered
via `link_at + inward·DOOR_INSET + opening_offset`, vs the 30×30 player box) shows
the closed doors make both edge triggers **unreachable** (no bypass) and the open
doors make them reachable (solvable). The slab is large enough to cover the neck's
innermost row/col even though its centre is one tile into the widening.

> **Carry to Step 5: `DOOR_INSET` must change.** The placeholders currently sit in
> the approach-clearance band, not the reserved door footprint (N rows 1-2 / E cols
> 45-46). Step 5's real door needs to move to the footprint — likely by reducing
> `DOOR_INSET` (safe: only `room_a` has doors) or making it per-link. Deferred here
> because door placement/art is explicitly Step 5.

**Reference files** added under `docs/m5-reference/`: `cistern-mask.txt`,
`cistern-layout.png`, `cistern-reference.png`.

> **On authority and staleness.** Now that the geometry lives in
> `data/rooms/room_a.json`, **that file is the authority** and the mask is a snapshot
> of where it started. The two **PNGs are a 2026-09-19 snapshot and will go stale**
> if the geometry changes — treat them as illustrative, not authoritative.

No `.tscn` files were edited in Step 4 (geometry is data; `room_a.tscn` only sets the
room id). `main.tscn` was edited back in Step 0.

---

## Post-Step-4 look pass (2026-09-19) — 2c, 2d, 3d

Steps from `docs/m5-next-steps.md`, worked after Steps 0–4.

**2c — corner bevels (built, owner signed off).** Rock corners are cut on a 45° line so
a diagonal run reads as a slope, not a staircase. The geometry is a new pure seam,
`scripts/rock/rock_bevel.gd` (`RockBevel`): convex/concave corner selection, the signed
cut, and the tile silhouette polygon — no autoload reference, so it is unit-tested
directly (`tests/test_rock_bevel.gd`, 23 cases) where `RockTileSet` can't be (it fails
to compile under `--script` on the `EnvPalette` identifier). `rock_tileset.gd` draws the
cut and seams the new diagonal; `RockStyle` gained `bevel_convex` (default 1.0) and
`bevel_concave` (default 0.0, off — inner corners read as "chipped rock", judge shoulders
first). **The collision polygon and the light occluder are driven by the same cut**
(`RockBevel.tile_polygon`), so the slope is solid, not painted-on — this **supersedes
§8's "collision stays a full square" rule**, which assumed a bevel the player couldn't
feel; the first pass (visual-only cut, square collision) was rejected on exactly that.
*Carry to 5a's seal test: beveled collision opens corner triangles, so a grid-only
flood-fill won't see a diagonal squeeze between two diagonally-touching rock cells.*

**2d — the player at final scale (built).** The placeholder square is now a procedural
humanoid drawn in `player.gd` `_draw` — the only character silhouette (spec §8), ~27×15
px (about a tile tall), static with 8-way facing from a head-lean plus eyes that hide
when facing away. Owner calls: procedural (not sprites), static (no walk cycle). Six
`@export` proportion knobs. `player.tscn` lost its `Body` ColorRect. Collision left at
30×30 (the validated footprint); the figure is narrower, so it floats slightly off
walls — an art-independent tightening left for later. Character *concept* (a generic
small humanoid) is a first pass, open to redirection.

**3d — scale/darkness check: SCALE STAYS (owner, 2026-09-19).** With the real tiles and
player in place, 960×540 is **not too tight** in the Cistern; the resolution ruling
(Q27) is **not reopened**. Judged on `godot .` with the backtick full-bright diagnostic
in `world.gd` (walk lit vs. dark — it read fine lit *and* dark). Zoom stays parked
(Q25). The debug toggle is kept for the 5d/M8 lighting work.

**4b — chime placement + shape lock: SHAPE FROZEN (owner, 2026-09-19).** Chimes moved
beside their doors in `data/rooms/room_a.json` (`door_tutorial [22,12] → [38,10]`,
`door_backtrack [10,6] → [27,6]`); placeholders, owner may still nudge. Owner chose to
**freeze the silhouette as-is** rather than break up the flats (the 33-tile bottom run
and a 7-row east straight) — the scrolling camera never frames a wall end-to-end and
5d/5e will dress them; rock stays **31.9%** (≈ the 30% line, accepted). **`room_a.json`
geometry is now LOCKED** — everything from 5a assumes it, and any edit must preserve the
openings, door footprints (N cols 23–24 / E cols 45–46 / S cols 32–35), clearances, both
stubs and rock near 30%. Validator green.

**5a — door placement fix (built).** `DOOR_INSET` 4 → **1.5** (now a float; computed in
world units off the link cell so the leaf centres between the footprint's two tiles):
both doors land centred in their reserved footprints (N (720,60), E (1380,420)) instead
of a tile past them in the clearance band. Doored-link entries land **room-side of the
slab** via a new `DOOR_ENTRY_INSET` (3.5) — the plain 1-tile landing dropped the player
inside the now-forward leaf; they now arrive on floor at `from_d` row 4 / `from_b` col 44,
clear of the slab and of the future door art (5b). The seal flood-fill is now a committed
script, **`scripts/seal_test.py`** (fine-grid, 72×90 slab vs 30×30 player, 8-connected):
each door **closed → edge trigger sealed, open → reachable**. The 72×90 blocker overlaps
the neck walls, so it seals and the 2c bevel opens no bypass at the door; the bevel's
diagonal-squeeze risk elsewhere stays an M7 whole-map concern. Clearances now empty.

- **Step 2 generates rather than loads** the atlas (owner, 2026-09-19) — keeps the
  palette retint.
- Banding shipped at **5 bands**, not the spec's suggested 3–4 start (owner tune).

**5b — door art (built, owner signed off 2026-09-20).** The N and E doors are now drawn
objects in their footprints: a carved stone slab (a lighter `rock_high` rim so it reads
as *cut*, not natural rock) with jamb + lintel framing a **brass organ-pipe** leaf
(deterministic varied cap heights, never RNG), retracting to a dark framed opening when
open. Orientation derives from the link's edge via a new **pure seam**,
`scripts`-free `DoorLayout` (`door_layout.gd`): it owns the `(across, depth)` frame so N
(faces south → gems/pipes below, horizontal) and E (faces west → gems/pipes left,
vertical) draw through **one path** — `DoorArt` and `DoorGems` never branch on edge, and
`room.gd` passes `door.facing = inward`. Unit-tested directly (`tests/test_door_layout.gd`,
12 cases) where `DoorArt`/`DoorGems` can't be (they reference `EnvPalette`). Gems moved to
the room-facing side; the M4 unlock choreography (flare/shake/dust) and `WorldState`
persistence are unchanged. Colours by palette name (no magenta): stone from the rock ramp,
`brass`/`copper` from `resonant`. **Owner note:** the pipe cap edge uses `copper` (#6B7F6A,
a sage-green) — reads as verdigris/patina rather than a bright highlight, kept as-is.
`door.gd` 175 / `door_gems.gd` 154 / `door_art.gd` 76 / `door_layout.gd` 34 — all under
the line guideline. Committed 07b8804 (with 5a, dea8a91, which had not been pushed).

**5c — the five-gem S door + the west gap (built).** The Cistern's unopenable five-note S
door is a **decorative object** (owner call, 2026-09-20: representation (b), no `MelodyLock`,
melody or link — the schema-level sealed exit (a) waits for M7). New `SealedDoor`
(`scenes/objects/sealed_door.gd`) reuses `DoorArt` for the carved-stone + brass-pipe leaf and
`DoorLayout` for orientation, so it reads as the same family as the real doors; it shows
**five unlit sockets** (owner call: count only, no category tint — drawn as empty stone
recesses with a carved rim, committing to no pitch→category, §9) and blocks with a permanent
`StaticBody2D` (nothing is behind it — the S corridor is a dead-end stub). Authored in data
(`room_a.json` new `sealed_doors` array, `at [33,35]`) and placed by the **same** footprint
math as a real door (`DOOR_INSET + opening_offset`, facing north). **No schema or validator
change** — `validate_rooms.py` reads only the graph, `seal_test.py` only doored links, and
`RoomGraph.geometry()` passes the new key straight through. The **west gap** needed no build:
it stays the geometry-only floor stub, reading as a free passage. Its faint brass self-light
is a placeholder for 5d.

**Opened-door look fixed (`DoorArt`, 2026-09-20).** An open door used to paint the full stone
slab then fill the opening with near-black `rock_void` — a flat black rectangle. It now draws
the stone as a **border** (two jambs + a lintel) and leaves the opening unpainted, so the
room's own floor shows through it as a passage, with a soft shadow under the lintel for depth.
The **closed** draw is byte-identical to the 5b sign-off; only the open branch changed. The
sealed door never opens, so it is unaffected.

**Standing caveat — the M5 art is provisional.** Everything visual here — the tileset, the
door frame / brass pipes / cap colour, the player figure, the socket treatment, the light
energies and every colour choice — is a placeholder. It will be revisited and polished in
later passes (M8 lighting, M9 detail, M10 doors-as-presentation, M13 audio) and by owner
redirection. Nothing recorded above is a final visual commitment; the point of M5 is only to
carry the Cistern to store-page quality, and any of it can change.

## Still open

- **Step 5 — compose the Cistern:** 5d light composition + the opened-door landmark (gems
  stay lit, frame light persists), 5e detail (capped). Owner-heavy. 5a/5b/5c built; the 5c
  visual gate (door visible, W reads as a gap) and the opened-door look are the owner's to
  confirm on `godot .`.
- **Step 6 — run the §1 gate, record; capture the reference still; silhouette test.**
