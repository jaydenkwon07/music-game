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
godot --headless --script tests/test_instrument_keyboard_layout.gd  # 21  (53 total)
python3 scripts/validate_rooms.py
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'
```

All green as of Step 4.

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

## Deviations from the spec, on the record

- **Step 2 generates rather than loads** the atlas (owner, 2026-09-19) — keeps the
  palette retint.
- Banding shipped at **5 bands**, not the spec's suggested 3–4 start (owner tune).

## Still open

- **Step 5 — compose the Cistern:** door as art object (frames/gems/brass), the
  five-gem act-2 door, light placement, `DOOR_INSET` fix. Owner-heavy.
- **Step 6 — run the §1 gate, record; capture the reference still; silhouette test.**
