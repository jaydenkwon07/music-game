# M5 — The cave look · Next steps

**Written:** 2026-09-19. **Basis:** `docs/m5-progress.md` (Steps 0–4 built and verified).
**Relation to the spec:** `docs/m5-spec.md` is unchanged and its Steps 5 and 6 stand.
This doc lists what is still between "Steps 0–4 built" and the §1 gate: work that
Steps 2–4 deferred, plus Step 5 split into buildable pieces. Where a step number
matches the spec, it means the same thing. Letter suffixes (2b, 4c…) are additions.
**Lifecycle:** scaffolding. When M5 closes, fold the outcome into
`docs/m5-progress.md` and delete this file (CLAUDE.md §12: trim, don't append).
**Gate (unchanged):** a still of the finished Cistern is something you would put on
a store page — owner's judgment on `godot .`. Secondary: a stranger shown a still
says more than "a pixel game".

---

## Where things stand

Built: 47-tile blob terrain, procedural atlas, 5-band light falloff, vignette (bloom
off), the Cistern's geometry (`data/rooms/room_a.json`, 48×36), and the 1440p
two-stage scale.

Known gaps in the current build — each is a step below:

1. **Corners stair-step.** The dome shoulders (mask rows 4–12, both sides) read as
   1-tile staircases. Terrain resolves them correctly; the atlas has no slope. Two
   earlier corner treatments were tried and removed (see 2c).
2. **Tile contrast was never tuned under light.** Step 2 deferred it to "Step 3/5
   lighting"; Step 3 has shipped, so it is due.
3. **The chimes are far from their doors.** `door_tutorial` at `[22,12]` is 21 tiles
   from the E door; `door_backtrack` at `[10,6]` is 13 from the N door. They were
   kept because the tiles were valid, not because they were well placed.
4. **Placeholder doors sit in the approach-clearance band** (N row 4 / E col 43), one
   tile past the reserved footprint.
5. **The player is a placeholder square** filling a whole tile.
6. **No five-gem door and no west gap yet.**

---

## Order of work

### 2b — Tile look pass under real light

Tune `rock_tileset.gd` against the Cistern's actual lights, not in the dark.

- Floor-versus-rock value gap in the *lit* state, so the room reads without leaning on
  the outline. (A mock-up used a floor about 1.7× the rock's brightness — a starting
  point only.)
- Strength of the contact band; floor grit variety (spatial hash, not RNG).
- A few sparse detail tiles (cracks, pebble clusters).
- Tiles stay flat, no baked light. Colours by `palette.json` name only. Expose the
  tuning numbers with `@export`.

**Done when:** standing in the hub, floor and rock are distinguishable at a glance.

### 2c — Silhouette: corners that read as slopes

Two earlier treatments failed: a half-tile chamfer (read as octagons) and a
`rock_void` inner notch (read as chipped rock). **Small masses are the stress test**
— the four outcrops are where an octagon shows first.

- Try a bevel on both convex and concave corner tiles, with leg length up to a full
  cell (`@export`), applied so consecutive corners join into a straight 45° line.
  Judge on the dome shoulders first, then the outcrops.
- Bevels cannot fix long straights (top edge 26 tiles, bottom ~27, east wall ~15
  rows). That is 4b.
- Fallbacks, in order: reshape the outcrops (data); the 4c overhang layer; a
  hand-drawn PNG atlas — **which reverses the Step 2 deviation and loses the palette
  retint, so it is the owner's call.**

**Done when:** a screenshot of a shoulder no longer reads as a staircase, and the
outcrops don't read as octagons.

### 2d — Player and interactables at final scale

The player sets the scale everything else is measured against. Draw the final
player, then re-check the pickup diamond and chime bar at that scale. Method
(procedural in `_draw`, as now, or drawn sprites) is the owner's call.

**Done when:** black-on-white silhouette test — player, pickup and chime are each
identifiable by shape alone.

### 3d — Scale and darkness check

Is 960×540 too tight in the Cistern, now with real tiles and the final player?

- Cheap test first: temporarily raise the light radius or ambient and walk the room.
  If it feels right lit, the problem is darkness, not the camera.
- **Zoom is not the fix.** It stays parked (design doc Q25): camera zoom only
  rescales and shimmers; the real form is a larger viewport, which means art at two
  densities. Only an explicit owner "yes, too tight" reopens the resolution ruling,
  and if so the plan stops here and is redone *before* more art.

**Done when:** owner records "scale stays" or "reopen".

### 4b — Chime placement and shape lock

Data-only, after 2c so the shape is judged with real corners.

- **Chimes:** move each beside its own door, outside footprints, clearances, stubs
  and outcrops. Suggested starting points: `door_tutorial → [38,10]`,
  `door_backtrack → [27,6]`; owner confirms. Clue delivery is still undecided, so
  these are placeholders, not design.
- **Shape lock:** decide whether to break up the long straights, then freeze the
  geometry. Any change to `room_a.json` must keep 2-tile openings, aprons, door
  footprints and clearances, both stubs, and solid rock near 30% or under.
- Everything from 5a onward assumes the geometry is frozen.

**Done when:** owner signs off on the silhouette. Validator green.

### 4c — Overhang (optional)

Rock drawn past the collision edge by up to a tile, Cistern only, collision
unchanged (spec §8 permits it). Skip if 2c and 4b are enough. The ladder puts
overhangs in M9, so doing it here pulls one room's share forward — **owner's call**,
recorded in the progress doc either way.

### 5a — Door placement fix

- Move the placeholder doors into the reserved footprints: N leaf rows 1–2 (cols
  23–24), E leaf cols 45–46 (rows 13–14).
- By the numbers, the footprint centres sit about 1.5 tiles from the link tile's
  centre on both edges, so one smaller `DOOR_INSET` may serve both. Verify against how
  `room.gd` computes `link_at + inward·DOOR_INSET + opening_offset`; make it per-link
  only if it does not.
- **Re-run the seal test:** closed doors make both edge triggers unreachable, open
  doors make them reachable. If that flood-fill is not yet a committed script, make it
  one — it catches a gate bypass the validator cannot see. Re-check the blocker size
  against the real leaf.
- Check `from_b [44,13]` and `from_d [23,5]` land on the room side of the moved doors.

**Done when:** seal test passes and both approach clearances are empty.

### 5b — Door art

The N and E doors as designed objects in their footprints: carved stone jambs, a
lintel, warm brass, tensioned strings or pipes (design doc §4.7), gems in a bar on
the room-facing side.

- **Orientation.** Today gems draw above the door regardless of edge. The art needs a
  facing derived from the link's edge (N faces south, E faces west).
- Keep the M4 unlock choreography working; keep `door.gd` and `door_gems.gd` under
  the line guideline. Gem hues from `NoteColors`; brass and stone by palette name.
- Doors show structure, never content.

**Done when:** silhouette test passes, and at a distance a door reads as a barrier and
an unmarked gap reads as a gap.

### 5c — The five-gem door and the west gap

- **S:** the five-gem door in its footprint (cols 32–35, rows 33–34), unopenable, no
  chime anywhere in Act 1.
- **Owner call before building — data representation.** (a) A real sealed exit (§7.5:
  `null` target plus a `sealed` tag; validator and boot check updated). Right
  long-term, but it touches the schema early. (b) A decorative door object with no
  `MelodyLock`, melody or link; no schema or validator change. Recommendation: **(b)
  for M5**, with (a) at M7 when the map needs sealed stubs. Also decide what the five
  sockets show; notes 4–5 are unassigned, so unlit sockets commit to nothing.
- **W:** stays open floor — no frame, no gems, no light. It only needs to read as a
  free passage next to framed doors.

**Done when:** the five-gem door is visible, the validator is green, and W reads as a
gap.

### 5d — Light composition and the opened-door landmark

The recipe is locked; placement is authoring.

- Door frame lights in warm brass, so the doors are the brightest things in the room;
  the sealed door dimmer.
- **An opened door stays a landmark:** gems lit and frame light persisting, restored
  when the room is re-instanced (`WorldState` already holds open doors).
- **Owner call:** any static lights beyond the interactables' own? Default is none,
  so darkness gates nothing and objects emit their own light.
- Band count stays at 5 unless retuned; bloom stays off.

**Done when:** in a hub still, the eye goes to the doors first.

### 5e — Detail (capped)

A small prop set: rubble, decals, floor detail. In a lit cave depth comes mostly from
light, so stop early if the room already holds. No faces, machinery or creatures
(spec §3). Each prop passes the silhouette test. **Owner sets the cap before this
starts**; a suggested ceiling is under ten pieces.

### 6a — Capture and judge

Capture the hero stills (the hub view, and one per door) and the reference still.
Run the silhouette test on the composed room. Owner judges §1: met, or explicitly not
met with reasons.

### 6b — The stranger test

Show a **still only**, not gameplay, and ask what kind of game it is. "A pixel game"
means the style has not landed; return to 2b, 2c or 5d, not to new content. Stills
keep the person fresh for M7's playthrough, which needs a fresh pair of eyes.

### 6c — Record

Write the final `docs/m5-progress.md`, with **hours per step** for M6's number. Trim
CLAUDE.md §2 and update its architecture entries for what changed (`rock_tileset.gd`,
`lighting.gd`, `door*.gd`). Update the design doc and handoff. The reference still is
what every later room is measured against. Delete this file.

---

## Owner calls, by the step they block

| Call | Blocks |
|---|---|
| Player size and animation scope; procedural or drawn | 2d |
| If procedural bevels fail: hand-drawn atlas (reverses the Step 2 deviation) | 2c |
| Is 960×540 too tight? | 3d |
| Confirm chime positions; break up the long straights? | 4b |
| Ship the overhang layer? | 4c |
| Sealed door: schema (a) or decorative object (b); what the sockets show | 5c |
| Static lights beyond the interactables | 5d |
| Prop cap | 5e |

Still not this milestone's business: which pitch classes map to which category,
combat, what each note does, the convergent finale, and how clues are really
delivered.

---

## Standing rules

- Colours resolve by name through `EnvPalette`; no hex in a scene or script. An
  unknown name returns magenta.
- The one rule: no pitch, melody or pattern in a `.gd` file.
- Floor variation is a spatial hash, never RNG.
- Collision stays on the 30px grid; the drawn silhouette may overhang by up to a tile.
- Transitions stay edge-band: 2-tile openings, mirrored `from_*` entries.
- Anything drawn passes the black-on-white silhouette test.
- Say so when a `.tscn` is edited, so the tab can be closed and reopened.
- If a step seems to need an owner call, implement nothing and ask.
- Log hours per step in `docs/m5-progress.md`.

## Non-goals (spec §3, unchanged)

Any other room; the eleven-room graph; note abilities; the boss door; audio of any
kind; the door panel redesign (camera push-in, keyboard-in-the-door); creatures,
props with faces, machinery beyond the doors. Also not here: a zoom feature or any
change to the internal resolution, unless 3d reopens it.

## Verification (re-run every step)

```
godot --headless --import
godot --headless --script tests/test_melody_matcher.gd              # 32
godot --headless --script tests/test_instrument_keyboard_layout.gd  # 21  (53 total)
python3 scripts/validate_rooms.py
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'
```

Plus the door seal test after any change touching doors or geometry (5a onward).
