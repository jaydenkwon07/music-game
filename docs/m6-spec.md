# M6 — Authoring pipeline and room two

> **RE-SCOPED 2026-09-20 (owner) — read this first.** No deadline, so the *measurement* half
> is dropped: no hours-per-room gate, no projection, no pre-registered ceiling (§1, §4 0b/0c,
> §5 minutes columns, §10 number, §11). The **pipeline + the Gallery to the M5 bar** stand.
> Revised gate: *the Gallery is at the M5 quality bar and the pipeline that made it cheaper
> exists.* Tools are judged by "does this remove a hand-error-prone step?", not hours saved.
> `tlog.py` is retained but optional. See `docs/m6-progress.md` for the current contract.

**Status:** in progress (re-scoped — see banner). Started 2026-09-20.
**Date written:** 2026-09-20.
**Inherits:** M5's reference still (`docs/m5-reference/cistern-final.png`) as the quality
bar; M5's carried debt (`room.gd` at ~300 lines); and one thing M5 did *not* deliver — a
measured hours-per-step figure.
**Record goes to:** `docs/m6-progress.md`. Raw time data goes to `docs/m6-time-log.csv`.

M5 built one room to final quality and did not record what it cost. The design doc named
the volume risk plainly — eleven rooms, solo, new to pixel art at 30px — and gave M6 one
job: turn it into a number before the rest of the schedule is committed to. M6 does two
things in a fixed order: **build whatever makes a room cheaper to author, then use it on a
second room and time every step.**

---

## 1. The gate

**A measured hours-per-room number**, with the evidence it stands on.

The gate is met when `docs/m6-progress.md` states the following, taken from the time log
and not from memory:

1. **Room two's cost, by pass** — geometry, content and wiring, light, detail, and owner
   review — plus the total to the M5 bar, the room's size in screens, and the number of
   review rounds it took.
2. **Pipeline cost, separately** — hours per tool, and the saving each tool claims.
3. **A projection for the rooms still unbuilt**, as a *range*, not a point, in a per-room
   and a per-screen form (§11), split by the passes M7, M8 and M9 will actually run.
4. **A coverage statement** — what fraction of the work was logged, and where the gaps are.
5. **The owner's verdict** — does the projection fit the plan, and if not, what changes.

**The quality condition.** A cheap room that is not at the bar measures the wrong thing.
Room two must sit in the same world as the Cistern: owner's judgment, room two's still
beside `cistern-final.png`. If it does not, the number does not count.

**Two things the gate is not.** It is not the pipeline's elegance — a tool that saved
nothing is a finding, not a failure. And the number is not a verdict: the gate is the
*measurement*. What the plan does about it is the owner's decision (§4, step 0c).

**Pre-register the threshold.** Before room two starts, the owner writes down the
hours-per-room at the bar that the plan can bear. If the measurement lands above it, the
plan is re-scoped rather than the number rationalised — candidate levers are in §11. The
owner may decline to pre-register; then the gate is "number produced and recorded", and
that weaker version is what the record must say.

---

## 2. Room two: the Gallery, replacing `room_b`

**Recommendation; the owner confirms before Step 1** (§13). The steps below hold for any
room — only this section changes if another is chosen.

**The pattern is M5's.** The Cistern replaced `room_a`, keeping its exits, so the art would
survive the map being built and the build stayed runnable with the validator green. Room
two does the same: the **Gallery replaces `room_b`** — the room behind the Cistern's east
door (`door_tutorial`) — keeping `room_b`'s id, entry names and outgoing links. It is in
the eleven-room map in that exact position (behind Door A), so nothing built here is
thrown away. Rooms take their real map names when M7 wires the graph.

**Why the Gallery.**
- **A different shape from room one.** The Cistern is a scrolling bell; the Gallery is the
  *shelf* — 3×1 screens, 96×18 tiles, scrolling horizontally. Same 1,728 cells as the
  Cistern (48×36), so per-cell cost is directly comparable, on a different axis.
- **Representative size.** The map is 26 screens across eleven rooms (1, 3, 3, 1, 1, 3, 6,
  2, 1, 1, 4). The Gallery's 3 is above the median (2) and near the mean (2.4). A one-screen
  room would flatter the number; the six-screen Choir would swamp it.
- **No puzzle in it** (design doc §3.8). Layout hours are not polluted by mechanics design,
  so the number measures *authoring*, not *deciding*.

**Considered and not chosen.**
- **The Hollow** (1 screen, via the Cistern's west stub). It needs graph surgery — a new
  link, moving the note-1 pickup and the spawn — which is M7's wiring, and it would
  contaminate the number. One screen also understates. It is the natural first M7 room.
- **Threshold** (carved, symmetric). Needs the back-opened shortcut door, which does not
  exist.
- **The Drip chamber.** Its exit is a note-ability gap; abilities are M11.
- **The Choir.** The largest room and the showpiece — measure it after the pipeline exists.

**Content already in `room_b` stays.** Any pickup, chime or door in the room being replaced
is kept and re-placed on valid floor outside the reserved zones — nothing removed, so the
validator's reachability claims hold (M5 ruling c). Chimes go beside their doors.

**The math the plan needs.** After M6, two rooms (6 screens) are built and **nine rooms /
20 screens** remain. The ladder's "that number times eleven" is now "times nine" — and, more
usefully, a per-pass figure per screen.

---

## 3. Non-goals

Real constraints, not suggestions (CLAUDE.md §11).

- **Any other room.** Not the Hollow, not the Drip chamber, not a third. One room, measured.
- **The eleven-room map graph.** No new links beyond what `room_b` already has.
- **Schema extensions for ability gates and sealed exits** (design doc §7.5). M7. The
  Cistern's five-gem door stays a decorative object.
- **Note abilities, the boss door, audio of any kind.** Unchanged. The synth stays a sine on
  purpose; M1's deferred gate stays correctly deferred.
- **Redesigning M5's art.** It is provisional and will be redone in later passes. Room two
  uses the M5 tileset, palette and door art. If the room needs a piece of *vocabulary* that
  does not exist — a new door type, a new prop — stop and ask; do not invent it.
- **The room-level silhouette / overhang layer.** `docs/m5-progress.md` records only the 2c
  tile bevels; treat that layer as not built. Overhangs are M9.
- **The door panel, zoom, any change to the 960×540 resolution.**
- **Tools nobody asked for.** A tool is built only if it pays for itself on the recon table
  (§5). "It would be nice" is not a reason.

---

## 4. Step 0 — Instrument before anything else

**0a. The time log.** `docs/m6-time-log.csv` plus a stdlib-only `scripts/tlog.py`
(`start`, `stop`, `note`, `report`) so logging costs seconds, not discipline. Fields: date,
start, end, category, step or tool, who, note. Categories: `pipeline`, `debt`, `geometry`,
`content`, `light`, `detail`, `review`, `decision`. `report` prints totals by category — the
gate reads it.

**Whose hours.** The number that schedules the project is the **owner's calendar time**:
design decisions, reviewing on `godot .`, iteration rounds. Claude Code's wall-clock is
minutes and is not the schedule. Owner time is required; Claude Code session counts are
optional.

**0b. A retrospective estimate for M5** — the owner's best guess of hours by pass, labelled
*ESTIMATE* with an error range. It is a sanity check on the measured number, never data.

**0c. Owner rulings, recorded in `docs/m6-progress.md` before Step 1:**
1. Room two (§2).
2. **Weekly hours available** (design doc Q34 — still `TBD`, and the projection cannot become
   calendar time without it).
3. The pre-registered ceiling (§1).
4. The pipeline stop-loss: total hours the owner will spend on tools before room two starts.

---

## 5. Step 1 — Recon: what adding a room costs today (report, then wait)

No building. Claude Code inventories, from the repo, the whole path for adding one room end
to end:

- Every file created or edited (`rooms.json`, `data/rooms/<id>.json`, the room scene,
  neighbours' entries and links, validator, tests).
- Every number derived by hand today — door footprints, approach clearances, the
  `DOOR_INSET` / `DOOR_ENTRY_INSET` arithmetic, stub zones, mirrored entries.
- Every check done by eye.
- The friction from M5's record: content coordinates left behind when a room was resized; the
  reserved-zone lists kept by hand in a text file; generator scripts living in chat sessions
  and not in the repo; `room.gd` at ~300 lines.

Output: a table — cost item, occurrences per room, minutes per occurrence, candidate tool,
build cost, saving over the nine remaining rooms. **The owner picks what is funded.**

---

## 6. Step 2 — The pipeline

Each tool is built only if the table shows saving × 9 rooms beats its build cost, only after
the owner's OK, and each is logged as `pipeline:<name>` against a cap. Candidates, in the
order the evidence suggests:

**2a. Split `room.gd`** (carried debt). Extract the `_build_*` content builders so new
content types stop growing a 300-line file. No behaviour change. Do it first: every later
tool and every content type touches this file. *Check:* the Cistern renders identically
(owner, `godot .`), boot check and validators green.

**2b. Room lint** (`scripts/lint_rooms.py`, stdlib, run beside the validator). The rules
that are currently checked by eye, as machine checks: 2-tile openings; a straight apron of
at least 4 tiles at every exit; mirrored `from_*` landings; **door footprints and approach
clearances derived from link positions with the same maths as `room.gd`** — not a hand-kept
list; nothing in a reserved zone or a stub; every content cell on floor; every exit reachable;
`size_tiles` matches the grid; rock percentage reported (target 20–30%; the Cistern is 29.9%
excluding outcrops, 31.9% including them). Errors versus warnings, with a fixture proving
each rule fires.

**2c. Room preview** (`scripts/room_preview.py`). Renders any room file to an annotated
image — grid, rock/floor/outcrop, exits, reserved zones, content, camera windows, rock % —
so the shape is judged before Godot is opened. It replaces the throwaway images made in chat
during M5. **No new dependency without the owner's OK;** if Pillow is not already in the dev
environment, emit SVG.

**2d. Room scaffold** (`scripts/new_room.py <id> <cols> <rows>`). Writes a valid skeleton —
solid rock, no exits — registers it, and creates whatever scene stub the recon says is
required, lint-green from the first save.

**2e. Generalise `seal_test.py`** to every room with doors, by room id.

**2f. Dev jump-to-room** (`godot . -- --room=<id> --spawn=<entry>`), *only if* the recon shows
walking to the room dominates review time. Debug-only, kept out of the release path like the
backtick toggle.

**2g. `docs/room-authoring.md`** — the recipe: archetypes, subtractive carving, the rules, the
order of passes, the checklist. **Written from doing room two, finalised at Step 6** — not
before, or it records guesses.

**What the pipeline is not.** No tile or atlas tooling (the procedural atlas stays), no GUI
editor, no new source format. **The grid in `data/rooms/*.json` stays the one source of
truth; tools read it and never replace it.** If the recon shows the grid is genuinely too
painful to hand-author, the answer is a generator that *writes* the same grid — and that is
its own owner decision.

**Stop-loss.** When the tool cap from 0c is reached, stop, and build room two with what
exists. An unfinished tool is a finding.

---

## 7. Step 3 — Room two, geometry pass

Logged as `geometry`. Author subtractively: the Gallery starts as solid rock in a 96×18
bounds and the walkable space is carved out.

- Natural rooms are irregular and asymmetric (design doc §3.8): the *shelf*, not a rectangle.
  Leave 20–30% of the bounds as rock the player never reaches.
- Every exit gets a flat apron and a 2-tile opening; the west opening mirrors the Cistern's
  east door. Keep `room_b`'s other exits where they point.
- The first time the camera scrolls **horizontally**: confirm the clamp behaves on a 96-wide
  room.
- Lint green; the preview looks right; then **the owner signs off the shape and the geometry
  is frozen**, exactly as the Cistern's was. Everything after assumes it.

---

## 8. Step 4 — Wiring and content

Logged as `content`. Replace `room_b`'s geometry, keeping its exits; re-place its content on
valid floor with chimes beside their doors; validator, seal test and boot check green. The
owner walks Cistern → Gallery → Cistern.

---

## 9. Step 5 — Light and detail, to the M5 bar

Logged separately: `light` and `detail`.

- **Light.** M5's ruling stands: no static lights beyond each object's own glow, doors are the
  beacons. A room with no new lights may cost close to nothing here. *That is a finding —
  record it.*
- **Detail.** Rubble only, under a cap the owner sets for this room (M5's Cistern: ≤5 pieces,
  very light). Cracks and finer detail are M9.
- Black-on-white silhouette test on the composed room. Capture the reference still — the F2
  capture key was removed at M5's close; re-adding it as debug-only is allowed if it saves
  review time, and is logged as `pipeline`.

---

## 10. Step 6 — The gate, and the record

- The owner judges §1: room two beside `cistern-final.png`. Same world, or not.
- Paste `scripts/tlog.py report` into `docs/m6-progress.md`; state the number, the range, the
  coverage, and the verdict against the pre-registered ceiling.
- Finalise `docs/room-authoring.md`. Save the still as `docs/m6-reference/gallery-final.png`.
- **Trim, don't append:** cut M6's build spec out of CLAUDE.md the same turn the next
  milestone is written in; refresh `docs/project-handoff.md` (§7, §14) and the design doc.

---

## 11. Turning one room into a schedule

Do not multiply by nine and stop. The ladder builds rooms in **passes** — M7 geometry, M8
light, M9 detail — and each pass scales differently:

| Pass | Scales with | So the number to carry is |
|---|---|---|
| Geometry (M7) | area, plus a constant per exit | hours per screen + hours per exit |
| Content and wiring (M7) | doors, links and objects | hours per door / per link |
| Light (M8) | number of objects | hours per object (may be ≈ 0) |
| Detail (M9) | area | hours per screen |
| Owner review | rounds | rounds per room × minutes per round |

Sizes for the nine rooms left: Hollow 1, Drip 1, Overlook 1, Stair 3, Choir 6, Span 2,
Threshold 1, Antechamber 1, Resonance 4 — **20 screens**. Two rooms (Choir, Resonance) hold
half of them. Carved rooms (Threshold, and the architecture that straightens toward the boss) likely
cost less geometry than natural ones. Report the projection as a low and a high, and say which
assumption separates them.

**Two caveats travel with the number.** The **look** cost is provisional, because the M5 art
will be redesigned; the **layout** cost is the durable part, so log them apart. And the
number is one sample of one room — say so.

**If it exceeds the ceiling**, the levers are: fewer rooms (the design doc weighed eight
against eleven), fewer passes per room, lower fidelity on connective rooms ("rooms are cheap,
notes are expensive" is a claim this milestone tests), or a longer calendar.

---

## 12. Verification

```
godot --headless --import
godot --headless --script tests/test_melody_matcher.gd              # 32
godot --headless --script tests/test_instrument_keyboard_layout.gd  # 21
godot --headless --script tests/test_rock_bevel.gd                  # 23
godot --headless --script tests/test_door_layout.gd                 # 12  (88 total)
python3 scripts/validate_rooms.py
python3 scripts/seal_test.py
python3 scripts/lint_rooms.py                                       # once it exists
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'
```

Plus the colour corollary (no hex in a scene or script; unknown names return magenta), and the
owner's `godot .` check that the Cistern is unchanged after Step 2a.

---

## 13. Open questions for this milestone

Owner's call. If a step appears to need one, implement nothing and ask.

1. **Confirm room two** — the Gallery replacing `room_b`, or another.
2. **Weekly hours available** (Q34).
3. **The pre-registered hours-per-room ceiling.**
4. **Which recon candidates are funded, and the pipeline cap.**
5. **Log method** — the CLI, or by hand; owner hours only, or Claude Code time too.
6. **The prop cap for room two,** and whether cracks wait for M9 (default: they wait).
7. **Whether to re-add a debug capture key.**

Unchanged and not this milestone's business: which pitch classes map to which category,
whether combat exists, what each note does, how the player learns a melody, and anything about
the convergent finale.
