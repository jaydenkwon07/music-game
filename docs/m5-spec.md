# M5 — The cave look

**Status:** spec. Not started.
**Date written:** 2026-09-18.
**Inherits:** M4's deferred Steps 3 and 5, and M4's unmet §1 gate, intact.
**Record goes to:** `docs/m5-progress.md`.

M4 built the technical visual foundation — render pipeline, palette, lighting,
silhouettes, motion — and consciously deferred the drawn art. M5 is that art. It
establishes the cave's visual language by building **one room to final quality**,
using the same vertical-slice logic every milestone so far has used: one room
finished, not nine at medium.

---

## 1. The gate

**A still of the finished room is something you would put on a store page.**

Inherited from M4 §1, unchanged. Secondary gate, also inherited: show it to
someone who has not seen the project and ask what kind of game it is. *"A pixel
game"* means the style has not landed.

Both gates are the owner's judgment on `godot .`, not a headless check.

**The standing silhouette test (M4 §8) still applies to anything drawn here:**
render the room black-on-white and confirm every interactable type is still
identifiable by shape alone.

---

## 2. The room is the Cistern

The finished room is the **Cistern** — the hub of the eleven-room Act 1 map
sketched during the 2026-09-18 re-planning session.

**Why this room and not one of M3's four.** Composing a room to final quality and
then discovering it is not in the shipped map is exactly the rework the
vertical-slice principle exists to prevent. The Cistern is guaranteed to survive:
it is the hub, everything routes through it, and the player sees it more than any
other room in the demo. It also earns the art three ways — it contains ordinary
exits *and* framed doors in the same frame (so the doors-versus-transitions
distinction gets proved visually), it contains the five-gem act-2 tease, and its
bell shape exercises the diagonal terrain work this milestone builds.

The cost, accepted: at roughly 1.5 × 2 screens it scrolls, which makes it the
most expensive room in the demo to finish first.

**Wiring.** The Cistern **replaces `room_a`** in the existing four-room graph,
keeping `room_a`'s exits pointing where they already point. The real map wiring is
a later milestone's job; this keeps the build runnable and the validator green
without half-migrating the graph. Its geometry carries over when the real map is
built — only its exits change.

---

## 3. Non-goals

Real constraints, not suggestions (CLAUDE.md §11).

- **Any other room.** Not the Hollow, not the Gallery, not Room B. The pipeline
  question — what does room two cost — is the *next* milestone's gate.
- **The eleven-room map graph.** No new `rooms.json` entries beyond the Cistern's
  own geometry.
- **Note abilities.** Categories stay data; nothing acts on them. (CLAUDE.md §6,
  §9.)
- **The boss door.** Unchanged, not started.
- **Audio of any kind.** The synth stays a placeholder sine *on purpose* — M1's
  deferred aesthetic gate must stay correctly deferred, and its trigger is the
  first real instrument voice. Do not introduce one here.
- **The door panel redesign** (camera push-in, keyboard-in-the-door). Door
  *presentation* is its own later milestone. M5 draws the door as an object in the
  room; it does not rework the instrument overlay.
- **Creatures, props with faces, machinery beyond the doors.** Rock is forgiving;
  faces and machinery punish inexperience (design doc §4.7).

---

## 4. Step 0 — Loose ends

Clear these before drawing anything. They are cheap now and each one is a thing a
fresh session would otherwise get wrong.

**0a. 1440p scaling.** `960×540` is integer-clean at 1080p (×2) and 4K (×4) but
**not at 1440p** — 1440/540 is 2.67. Letterboxing there leaves 44% of the screen
black, which is worse than any filtering artifact. Fix on the `Display`
`TextureRect` in `main.tscn`/`main.gd`: upscale nearest-neighbour to the largest
integer multiple that fits, then resample *that* to the window with bilinear. The
integer step fixes pixel shape; the fractional step resamples an
already-correct image, so there is no shimmer during movement.

Record the trade in the design doc: the 640×360 → 960×540 bump traded clean 1440p
for finer detail, and 640×360 was clean at all three. The design doc §3.7 still
claims 1440p as a target and is now wrong.

**0b. CLAUDE.md is stale in three places.** §4 annotates `note_pickup.gd` and
`melody_chime.gd` as *"still a bare circle — D-M4-7"*; §6 calls the defect
*"currently live."* Both are fixed (M4 Step 4). §5 still says rooms are *"32×18
tiles at 20px"*; tiles are 30px. A fresh session reads this file and believes it
(§12) — right now it would go re-fix a closed defect.

**0c. M3's play-through gate — WAIVED** (owner, 2026-09-18). Resolved, not
pending. The two things it would have caught are both fixed: chimes now read as
chimes rather than dimmed pickups (D-M4-7), and the gem-hue disagreement was ruled
intended (D-M3-3). The stronger version of the same gate — a stranger playing the
full eleven-room map — belongs to M7, and the scarce resource it needs is a fresh
pair of eyes, wasted on four rooms about to be superseded.

The step here is only to **write the waiver down** in CLAUDE.md §2 and the ladder,
with the residual risk named: the loop's legibility is formally unvalidated until
M7, so **M7's gate must not be waived in turn.**

**0d. Roadmap.** CLAUDE.md §8's ladder still lists the old M5/M6/M7 rows. Update
to the re-planned ladder in the same change that lands this spec.

---

## 5. Step 1 — Tileset architecture

This is the decision hiding inside "draw a tileset," and it has to be settled
before a pixel is drawn.

**The problem.** `room.gd` currently computes a **16-tile adjacency mask** by
hand and `rock_tileset.gd` builds the atlas procedurally. Sixteen tiles is the
corners-only set: it can only produce axis-aligned walls. A meaningful part of why
the current build reads as rectangular is that *the tool cannot express anything
else*. Swapping in drawn tiles at sixteen tiles keeps the rectangles.

M4's progress note that real tiles drop in *"with no other change"* is true only
at sixteen tiles.

**DECIDED (owner, 2026-09-18): the 47-tile blob** — Godot 4's built-in "match
corners and sides" terrain mode. The option that lost is kept below, because a
reversal is cheap only while the reasoning is on record.

| | 47-tile blob | 256-tile diagonal |
|---|---|---|
| Source | Godot 4 built-in terrains, "match corners and sides" | Terrain Autotiler plugin, full 256-tile mode |
| Gives you | Rounded and irregular edges, axis-aligned | The above plus true diagonal wall runs |
| Cost | Fewer tiles to draw, no plugin | More tiles, a third-party dependency |
| Generation | Tilesetter / TilePipe2 from a small source set | Same tools; more source work |

**Why blob.** It is the built-in path with no third-party dependency, 47 tile
images instead of 256, and it is enough to kill the 90° corner: it distinguishes
inner corners from outer ones, and a corner tile drawn as a 45° bevel makes a
staircase of cells read as a smooth slope. The case 256 uniquely handles —
**corner-only contact**, two rock cells touching at a single corner with floor on
both cardinals between them — essentially never arises in this cave, where the
rock masses are several cells thick. 8-directional movement makes the resulting
rounded and beveled edges playable rather than awkward.

**The upgrade path stays open.** If the drawn result still reads too orthogonal,
256-tile (via the Terrain Autotiler plugin) is an upgrade, not a rebuild: the
drawn rock is identical and only the transition set grows. Don't hardcode an
assumption that 47 is the ceiling.

**What changes in code:**

- `rock_tileset.gd` stops *generating* an atlas and starts *loading* a drawn one.
  It remains the only file that knows how a tile looks — that property is what
  made this swap cheap and must survive it.
- `room.gd`'s hand-rolled wall mask is **replaced by Godot's terrain system.**
  Room geometry data still drives which cells are rock and which are floor; the
  engine picks the tile.
- **Keep the per-cell floor variant as a spatial hash, not RNG** (CLAUDE.md §4).
  Terrain handles edges; floor variation is still ours, and a room that looks
  different each time it is re-instanced is the bug this rule prevents.
- 30px tiles are off-convention (tooling assumes 16/32/48) and half-tile detail
  lands on an odd 15px. Not a reason to move — just set tile size explicitly
  everywhere and expect friction with any generator.

**Gate for this step:** paint a rough non-rectangular blob in the editor and
confirm the edges resolve correctly, with the placeholder atlas, before drawing
anything.

---

## 6. Step 2 — Draw the rock

The tileset itself. Constraints, most of which are already locked:

- **Flat, with no baked lighting** (M4 §8a / D-M4-10). Tiles drawn with shading
  will be lit a second time by the dynamic lights and go muddy. A tile should look
  slightly boring alone and correct in the room.
- **The locked 7-tone hue-shifted rock ramp** from `data/palette.json`. Shadows
  drift violet, highlights drift warm. This single habit is most of the gap
  between amateur and polished pixel art.
- **No saturated colour.** The twelve note hues stay the only saturated colours in
  the game, and they belong to the player, not the world (design doc §4.7).
- **Draw order is tileset → player → interactables → doors → props.** The tileset
  sets the value range everything else lives inside. Drawing the exciting things
  first yields objects that do not sit together.

**Author subtractively.** The room starts as solid rock and the walkable space is
carved out of it. This is a habit, not a code change, and it is most of what makes
a cave stop looking like a floor with blocks on it.

Deliverables: floor tiles with variants, wall body, the full transition set for
the chosen terrain mode, the wall-meets-floor seam, and a small number of detail
tiles. Props come later and are fewer than expected — in a lit cave, depth comes
mostly from light falloff rather than drawn detail.

---

## 7. Step 3 — Light falloff and post-processing

Two rendering jobs that are worth more than drawing skill here, and both were
built to be hostable by M4's pipeline.

**3a. Band the light falloff.** `lighting.gd` uses one cached *soft radial
gradient*, which currently renders as a smooth blur — the only thing on screen
that is not made of pixels, and a strong tell. Quantise the gradient texture into
a small number of hard steps (start with 3–4) so the falloff reads as bands of the
rock ramp rather than as a PNG laid over the tiles. This is a change to the
gradient stops, not to the lighting model, so it is cheap and reversible.

**3b. Attach post-processing.** Deferred from M4 with the pipeline built to host
it. Effects attach to the `Display` **after** the upscale, not before — applying
them at internal resolution is one of the five things the "2000s pixel game"
diagnosis named. Start with a vignette; treat bloom as optional and be
conservative with it, since a world that already glows undercuts the
emptiness-to-fullness arc.

**3c. Interior masses are rock, not holes.** Current interior obstacles draw as
pure black rectangles, which read as *absence of tile*. An interior mass should be
an outcrop of the same material, lit by the same lights.

---

## 8. Step 4 — Carve the Cistern

Geometry before composition. The Cistern is a **bell**: a wide floor, high sloped
walls, and openings at three different heights.

- **Leave 20–30% of the bounds as solid rock the player never reaches.** The
  current rooms read rectangular partly because the carved space fills nearly the
  whole bounds rect. Camera limits need a rect; the *room* does not have to be one.
- **Diagonal and irregular wall runs**, now that the terrain set can express them.
- **Every exit gets a flat apron.** Edge-band transitions need a short straight
  stretch at the boundary with 2-tile openings and mirrored `from_*` entries
  (CLAUDE.md §5). Irregular walls and this convention fight unless the apron is
  authored deliberately.
- **Doors need a tile or two of approach clearance** so the instrument state is not
  entered flush against a screen edge.
- **Collision stays on the 30px grid; the drawn silhouette may overhang it** by up
  to a tile. The player cannot tell — it is impassable either way — and it is how
  the outline stops looking like a grid.

Validator must pass on the modified room. The 53 unit tests are untouched by this
milestone and must stay green.

---

## 9. Step 5 — Compose the Cistern

Composition, lighting placement and the door as an art object.

- **Doors must read as barriers, not as exits.** Currently a door is a dark
  rectangle with gems above it, which from a distance is also what an unmarked gap
  looks like. The door needs a frame that reads at a glance — carved jamb, lintel,
  warm brass against cold stone (design doc §4.7). This is the single most
  important art deliverable in the room, because the map's whole structure depends
  on the player scanning a room and knowing which openings are free.
- **The five-gem act-2 door** is placed here, unopenable, with no chime anywhere.
  The gem count is the entire Act 2 promise and it costs nothing but placement.
- **Light placement is authoring, not tuning.** The recipe is locked from M4; where
  the lights go in this room is a compositional decision and is most of what makes
  the room feel authored.
- **An opened door should stay a landmark** — gems lit, frame light persisting —
  so it is visible from the next room. Free wayfinding.

---

## 10. Step 6 — Run the gate, record it

- Owner runs `godot .` and judges §1. Met, or explicitly not met with reasons.
- Capture the reference still. Every later room is measured against it.
- Black-on-white silhouette test on the composed room.
- Write `docs/m5-progress.md`. Trim M5's build spec out of CLAUDE.md the same turn
  the next milestone is written in — this file has drifted once already by only
  ever growing (CLAUDE.md §12).

---

## 11. Verification

```
godot --headless --import                                  # parse check
godot --headless --script tests/test_melody_matcher.gd     # 53 tests, must stay green
python3 scripts/validate_rooms.py                          # must pass on the modified room
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'        # the one rule — must return nothing
```

Plus the environment-colour corollary: no hex literal in a scene or script; every
environment colour resolves by name through `EnvPalette`, and an unknown name
returns magenta so a typo shows.

---

## 12. Open questions for this milestone

Owner's call. If a step appears to need one, implement nothing and ask.

- **How aggressive the falloff banding is** — 3 bands is a strong stylistic
  statement, 5 is subtle. A feel judgment, `@export` it.
- **Whether bloom ships at all.** Vignette is safe; bloom risks undercutting the
  darkness the cold open depends on.

Unchanged and still not this milestone's business: which pitch classes map to
which category, whether combat exists, what each note does, anything about the
convergent finale.
