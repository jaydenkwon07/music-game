# M7 — The grey-box map (design)

**Milestone:** M7 (CLAUDE.md §8). **Date written:** 2026-09-22. **Status:** design approved
(owner, brainstorming session 2026-09-22); one open conflict to resolve before geometry (§9 C1).

**Authoritative sources, in precedence order for their domain:**
- **Design intent / the map:** `Resonance — Act 1 room layout` (owner PDF, 2026-09-21) and the
  Master Design Document V8 §3.7/§4.3/§7.5. The layout PDF is the map's authority; the owner
  ruled it "implement as drawn" on 2026-09-22.
- **Code / current build state:** `CLAUDE.md` (this repo) and `docs/m6-progress.md`.
- **Process:** `docs/room-authoring.md`.

Where a source disagrees with another, that is a **flag to resolve, not a new ruling** — see §9.

---

## 1. What M7 is

Replace the M3 grey-box wiring with the **real eleven-room Act 1 map**: a descent that loops
back to the hub, connected, gated, and provably solvable, playable end-to-end from a cold open
in the Hollow to the boss door opening in the Resonance chamber.

**Fidelity: grey-box.** M7 authors each new room's **archetype geometry** (the silhouette shape
— throat, pit, ledge, shaft, cathedral, crossing, carved, ring — which is layout, not art) plus
its wiring, gating and content. It does **not** run the light pass (M8), the detail/decoration
pass (M9), the door-presentation pass (M10), note ability *behaviours* (M11), boss-station
*mechanics* (M12), or audio (M13). The two already-finished rooms — Cistern (`room_a`, M5) and
Gallery (`room_b`, M6) — stay at their final quality, untouched except for graph wiring and
content re-placement that does not alter their frozen geometry.

**Note count: three** (owner, 2026-09-22, resolving design-doc Q17). The map is built exactly as
drawn: three notes, four ordinary melody doors plus the boss door, door ramp `1, 2, 3, 3`. Five
notes is explicitly not this milestone (it would reopen the map — the drawn map has no rooms for
notes 4–5).

### 1.1 The gate — do not waive

**M7's gate is a stranger playing the full eleven-room map unprompted, Hollow → boss.** It
carries M3's play-through gate, which was waived on 2026-09-18 on the explicit condition that
M7's stronger version is run (CLAUDE.md §2). **This gate must not be waived in turn.** The
residual risk M3 accepted — the loop's legibility is unvalidated until M7 — comes due here.

### 1.2 Non-goals (real constraints, CLAUDE.md §11)

- No light, detail, door-panel/camera-push, note abilities, boss mechanics, or audio (as above).
- **No redesign of the drawn map.** Sizes, archetypes, gates and topology are fixed inputs.
- **No edit to the Cistern's or Gallery's frozen geometry — with one approved exception:** a
  single controlled carve of a fifth Cistern opening/stub for the shortcut landing (§9 C1,
  owner-approved 2026-09-22), which gets its own sign-off and re-freeze and must preserve the M5
  reference-still read. Nothing else in either locked room changes shape.
- **No new note ids and no pitch-class→category assignment.** The three existing placeholders
  already fit the map (§4.3); §9 of the design doc stays deferred.
- **No real melodies.** Door melodies stay `placeholder: true`; the owner composes later.
- **No fifth room-content vocabulary invented to fill a dark room.** A doorless, chime-less room
  is dim by design (M5 light ruling); that is a pacing contrast, recorded as a finding, not a gap.

---

## 2. The map (authoritative topology)

Critical path, in play order:

> Hollow → Cistern → **Door A** → Gallery → Drip → Overlook → Stair → **Door B** → Choir →
> Span → **Door C** → Threshold → *shortcut* → Cistern → **Door Ω** → Antechamber → Resonance.
> The demo ends when the boss door opens.

```
                 ┌──────────────┐  Ω·3   ┌──────────────┐        ┌──────────┐
                 │ Antechamber  │◀───────│   Cistern    │──A·1──▶│ Gallery  │
                 │  (carved)    │        │  hub · bell  │        │  shelf   │
                 └──────┬───────┘        └───▲──────┬───┘        └────┬─────┘
                        │                     │      │                │
                 ┌──────▼───────┐   shortcut  │      │ W(free)        ▼
                 │  Resonance   │  (one-way,  │   ┌──┴───┐      ┌──────────┐
                 │ ring · boss  │   back-door)│   │Hollow│      │  Drip    │ note2
                 └──────┬───────┘             │   │note1 │      │  pit     │
                        ┆ sealed              │   └──────┘      └────┬─────┘
                     Act 2                    │                 (ability gate: note2)
                                              │                      ▼
   S(Cistern): 5-gem sealed door ────────┐    │                ┌──────────┐
   (decorative, no chime, promises Act2) │    │                │ Overlook │
                                         │    │                │  ledge   │
   ┌──────────┐  C·3   ┌──────────┐      │    │                └────┬─────┘
   │Threshold │◀───────│  Span    │◀──┐  │    │                     ▼
   │ carved   │        │ crossing │   │  │    │                ┌──────────┐
   └────┬─────┘        └──────────┘   │  │    │                │The Stair │
        └── shortcut ─────────────────┴──┘    │                │  shaft   │ chime
            (Threshold → Cistern)  (ability   │                └────┬─────┘
                                    gate:note3)│                 B·2 │
                                               │                     ▼
                                               │                ┌──────────┐
                                               └── note3 ───────│The Choir │ note3
                                                                │cathedral │ chimes
                                                                └──────────┘
                                                         (free exit → Span; sealed east passage)
```

Solid edges are the critical path; the shortcut and the sealed exits are one-way / dead ends.

### 2.1 Two long-range payoffs (geometry constraints that survive into M7 even though light is M8)

1. **Door Ω sightline.** Door Ω sits in the Cistern (north), seen at ~minute 3 while the player
   holds one note, opened at ~minute 25. The Cistern is already built, so this is satisfied.
2. **The Choir's light through the Overlook chasm.** The Choir's chime-light must plausibly rise
   through the Overlook's chasm ~10 minutes before the player arrives. M7 does not place the light
   (M8), but must author the **geometry** so it is possible: the Choir and the Overlook vertically
   related, with an open shaft between the Overlook's floor-chasm and the Choir below it. Placing
   these two rooms so the shaft lines up is an M7 geometry obligation.

---

## 3. Schema extensions (the code core)

Three things the current data contract cannot express. Only the first is genuinely new schema;
the other two are modelled with existing mechanisms (deviations from the layout doc's suggestion,
flagged for the owner in §9).

### 3.1 Ability-gate edges — NEW schema

The Drip exit and the Span bridge are crossed with a note ability, not opened with a melody. The
graph must distinguish them, or the validator certifies a map the player cannot cross.

**Data.** An exit in `data/rooms.json` carries **either** a melody door **or** an ability
requirement, never both:

```json
{ "to": "room_overlook", "to_entry": "from_drip", "requires": { "note": "n_step" } }
```

- `requires.note` is a note **id** (resolved through `data/notes.json`), never a pitch — the §3
  one-rule holds.
- An exit has at most one of `door` / `requires`. A validator error if both.

**`scripts/validate_rooms.py`.** In the reachability fixpoint, an exit with `requires` is
passable iff the required note's pitch class ∈ the pitch classes the player owns at that point
(the same `owned_pcs` set already computed for doors). Referential integrity: `requires.note`
must be a known note id. The door length-ramp check does **not** apply to ability gates.

**`scripts/roomlib.py` / `lint_rooms.py`.** An ability-gate opening is an ordinary 2-tile
perimeter opening with an apron and a mirrored landing; the lint treats it exactly like any other
link for geometry purposes. No new geometry rule.

**In-game (`room.gd` / `RoomContent` / `objects/room_link.gd`).** The ability-gate link's
edge-band trigger is **inert until `NoteInventory` holds the required note**, then it transitions
like any other edge-band link. In M7 grey-box, *owning the note opens the passage* — which is
exactly what the validator models. The dressed behaviour (visibly jumping the Drip gap, mending
the Span bridge) is **M11** and out of scope; the M7 obstacle is a plain impassable band the link
ignores until the note is owned.

**Tests.** Add validator unit coverage: an ability gate is impassable without the note and passable
with it; a map whose only route through a gate lacks the note is reported unsolvable; `requires`
+ `door` on one exit errors; unknown `requires.note` errors. Add a game-side test that a
`room_link` with `requires` does not transition until `NoteInventory` reports the note owned.

### 3.2 Sealed exits — NO new schema (⚠ deviation from layout doc, owner-confirmed §9 D1)

Three spots are deliberate dead ends: the Cistern's 5-gem door, the Choir's east passage, and the
Resonance chamber's onward exit to Act 2. The layout doc suggests a null-target graph edge with a
`sealed` tag. **This spec instead models all three as `sealed_doors` room-content entries with no
graph edge** — the mechanism the Cistern's 5-gem door already uses (`{ "at": [c,r], "sockets": n }`),
which already passes `lint_rooms` and `validate_rooms`. A sealed door is an opening in the room
geometry with a decorative `SealedDoor` object and **no entry in that room's `links` / that room's
`rooms.json` exits**, so there is nothing dangling for the validator to flag. Net schema surface:
zero. (The flowchart's dashed edges to sealed nodes are narrative, not graph edges.)

New sealed doors M7 adds: the Choir's east passage (`sockets` per the doc — decorative) and the
Resonance→Act 2 exit. The Cistern's 5-gem stays as-is.

### 3.3 The one-way shortcut — NO new schema (⚠ see the open conflict, §9 C1)

Threshold → Cistern, a door opened from its back: from the Threshold side it shows no gems and
asks for nothing; from the Cistern side it reads as a sealed frame (gems facing the hub) that is
never opened.

**Graph model:** a **non-reciprocal free edge**. `room_threshold` has an exit
`{ "to": "room_a", "to_entry": "from_threshold" }` with no `door` and no `requires`. The Cistern
has **no** reverse exit — so the validator can never call it "unsolvable" (there is no
Cistern-side door edge), and the player cannot walk back. The Threshold-side gets a normal
edge-band trigger; both faces get decorative door art in M10 (not M7). No new graph field.

**Must confirm in code:** that `validate_rooms.py` and `seal_test.py` tolerate a **non-reciprocal**
edge (every existing edge today is reciprocal). If either assumes reciprocity, relaxing that
assumption is the *only* shortcut-related code change. This is expected to be a no-op for
`validate_rooms` (it reasons about forward reachability) and for `seal_test` (it only checks
doors that have a lock; a free edge has none).

**Landing (§9 C1, resolved):** the Cistern gets a fifth opening/stub carved for the shortcut, and
a `from_threshold` entry at that stub cell. This is the one approved edit to frozen geometry
(§1.2); it is carved with owner sign-off and re-frozen (§6, Step 3a).

---

## 4. The room graph (`data/rooms.json`) and content

### 4.1 Ids and disposition

- **Keep** `room_a` (Cistern) and `room_b` (Gallery) ids — geometry locked. **Fix** `room_a`'s
  stale `display_name` `"Threshold"` → `"Cistern"`; it currently collides with the *actual*
  Threshold (room 9). Fix `room_b`'s `display_name` to `"Gallery"` if not already.
- **Retire** `room_c` and `room_d` (M3 grey boxes, not in the map). Delete their
  `data/rooms/room_c.json` / `room_d.json` and their graph entries.
- **Nine new rooms**, descriptive ids: `room_hollow`, `room_drip`, `room_overlook`, `room_stair`,
  `room_choir`, `room_span`, `room_threshold`, `room_antechamber`, `room_resonance`.
- **Start** moves to `{ "room": "room_hollow", "entry": "spawn" }` (cold open; today it spawns in
  the Cistern).

### 4.2 Gates and melodies

| Gate | Type | Between | Gems | Notes |
|---|---|---|---|---|
| Door A | melody | Cistern → Gallery | 1 | `door_tutorial` (exists), chime in the hub |
| Drip exit | **ability** (`requires n_step`) | Drip → Overlook | — | crossed with note 2 |
| Door B | melody | Stair → Choir | 2 | new `door_b`, chime partway down the shaft |
| Span bridge | **ability** (`requires n_mend`) | Span (across) → Door C side | — | mended with note 3 |
| Door C | melody | Span → Threshold | 3 | new `door_c`, hardest ordinary door |
| Shortcut | free one-way | Threshold → Cistern | none facing | §3.3, §9 C1 |
| Door Ω | melody | Cistern → Antechamber | 3 | new `door_omega`, clued by 3 fragment chimes |
| Boss door | stations | within Resonance | 3 stations | mechanics deferred to M12; M7 places station markers only |
| 5-gem | sealed content | Cistern (S) | 5 unlit | exists, decorative |

**Melody solvability constraint (validator-enforced).** A door's placeholder melody may use only
the pitch classes owned when the player first reaches it, or `validate_rooms` fails:

- Note collection order on the critical path: note 1 `n_break` (C, Hollow) → note 2 `n_step`
  (E, Drip) → note 3 `n_mend` (D, Choir).
- **Door A** (1 note held: C) → melody ⊆ {C}. `door_tutorial` = `[C4]` ✓.
- **Door B** (2 notes held: C, E) → melody ⊆ {C, E}, length 2.
- **Door C** (3 notes held: C, E, D) → melody ⊆ {C, D, E}, length 3.
- **Door Ω** (opened last, 3 notes held) → melody ⊆ {C, D, E}, length 3.

All new melodies are authored `placeholder: true`, `octave_matters: false`, `order_matters: true`
(matching `door_tutorial`), drawing only from the owned pitch classes above. Real pitches are the
owner's, later.

### 4.3 Pickups, chimes, content re-placement

- **Pickups (repositioned, no new ids):** `n_break` → Hollow (far end, "where light begins"),
  `n_step` → Drip, `n_mend` → Choir (bottom). Remove the Gallery's current `n_mend` at `[16,8]`
  (the layout gives the Gallery no content). This is a content change only; the Gallery's frozen
  geometry is untouched, and reachability is preserved because `n_mend` is now collected in the
  Choir, before Door C / the Span need it.
- **Chimes:** Door A → a chime in the Cistern hub (exists). Door B → a chime partway down the
  Stair. Door Ω → **three fragment chimes** in three separate rooms (the only gate that asks the
  player to remember across the map). Place chimes beside/along the path to their door per the
  authoring recipe.
- **Note→category already fits the drawn map:** note 1 destructive (`n_break`), note 2 movement
  (`n_step`), note 3 restorative (`n_mend`). No §9 pitch-class decision is required for M7.

---

## 5. The nine rooms to author (fixed inputs from the layout PDF)

Sizes in screens (1 screen = 32×18 tiles at 30px = 960×540). Author subtractively; 20–30% of the
bounds stays unreachable rock (a lint warning, higher for long thin rooms by construction).

| # | Room / id | Size | Archetype | Key layout obligations |
|---|---|---|---|---|
| 1 | Hollow `room_hollow` | 1 | throat (nat.) | cold open in darkness, no UI; note 1 at the far end; free gap into the Cistern **west** (rows 26–27, mirror the locked opening) |
| 4 | Drip `room_drip` | 1 | pit (nat.) | note 2; its **own exit is the ability gate** (`requires n_step`); free entry from the Gallery **south** (mirror the Gallery's locked S opening cols 84–85) |
| 5 | Overlook `room_overlook` | 1 | ledge (nat.) | floor opens into a chasm; look *across*; the chasm must line up with the Choir below for M8 light (§2.1) |
| 6 | The Stair `room_stair` | 1×3 vert. | shaft (nat.) | vertical descent past staggered ledges; a chime partway down; **Door B** (2 gems) at the bottom; first vertical-scroll room — confirm the camera clamp |
| 7 | The Choir `room_choir` | 3×2 | cathedral (nat.) | showpiece; note 3 at the bottom; chimes at different heights; **Door B** entry from the Stair; free exit toward the Span; **sealed east passage**; light-shaft alignment to the Overlook (§2.1) |
| 8 | The Span `room_span` | 2×1 | crossing (nat.) | a fissure with a collapsed bridge; **ability gate** (`requires n_mend`) across the fissure; entry from the Choir; **Door C** (3 gems) into Threshold |
| 9 | Threshold `room_threshold` | 1 | carved chamber | **first deliberately-built room: symmetric, straight-walled**; **Door C** entry from the Span; the back of the **one-way shortcut** into the Cistern |
| 10 | Antechamber `room_antechamber` | 1 | carved | behind Door Ω; goes dark again on purpose (a quiet beat); exit onward to the Resonance chamber |
| 11 | Resonance `room_resonance` | 2×2 | ring (carved) | the boss door; **three station markers** around the ring (mechanics M12 — M7 places markers and the melody-is-the-route geometry only); **sealed onward exit** to Act 2 |

**Geometry-language rules every room obeys** (from the layout doc / `docs/room-authoring.md`):
natural rooms irregular and asymmetric; **carved rooms (Threshold, Antechamber, Resonance)
symmetric and axis-aligned — the architecture straightens as the player nears the boss**; every
opening 2 tiles wide with an edge-band trigger; every exit a flat straight apron ≥ 4 tiles; each
opening **height-matches its neighbour's locked/frozen geometry**; collision and (future) light
occluder follow the drawn 45° bevel.

---

## 6. Build sequence (skeleton-first, owner-approved)

Rationale: M7's gate is "connected, gated, validated." Skeleton-first makes that an invariant held
from the start and only improved, and front-loads the schema/graph-integration risk before any
geometry effort. "One room first, then the batch" applies to the carving pass (Step 3).

**Step 0 — Pipeline (only what earns its keep at 9× rooms).**
- `scripts/new_room.py <id> <cols> <rows>` — writes a lint-green solid-rock skeleton and registers
  it in `rooms.json`. (Pays off standing up nine rooms; M6 skipped it at 1×.)
- A debug **jump-to-room** flag: `godot . -- --room=<id> --spawn=<entry>`, kept out of the release
  input path like the backtick full-bright toggle. (Pays off owner review of nine rooms.)
- The annotated-preview tool stays **deferred** unless Step 3 shows it removes a concrete step
  (owner reviews on `godot .` anyway) — consistent with M6's "smallest thing that works."

**Step 1 — Schema.** Implement §3.1 ability-gate edges end-to-end (data contract, `validate_rooms`,
`roomlib`/lint tolerance, `room_link` ownership gate) with the §3.1 tests. Confirm §3.3
non-reciprocal-edge tolerance in `validate_rooms` + `seal_test`. No rooms yet.

**Step 2 — Skeleton graph (the spine; the gate property is achieved here).** Rewrite
`data/rooms.json` to the full eleven-room graph: real ids (§4.1), all gates (§4.2: Doors
A/B/C/Ω, Drip & Span ability gates, sealed doors) **except the shortcut edge, which waits for its
Cistern landing in Step 3a**, the three rewires
(Cistern-N → Antechamber, Gallery-S → Drip, start → Hollow), pickups (§4.3), and chimes. Scaffold
the nine new rooms as **minimal grey boxes** at the correct sizes with openings mirrored to their
neighbours. Author the new placeholder melodies (`door_b`, `door_c`, `door_omega`) within the §4.2
pitch-class constraints. **Green bar:** `godot --headless --import`, `validate_rooms.py`,
`seal_test.py`, `RoomGraph` boot check, and a full manual walk Hollow → boss.

**Step 3 — Carve to archetype, one room at a time in play order.** Hollow first (proves the M7
room pipeline incl. Step 0 tools), then the batch (Drip, Overlook, Stair, Choir, Span, Threshold,
Antechamber, Resonance). Each room: carve to its archetype (§5) → `lint_rooms` green → **owner
signs off the shape on `godot .`** → **freeze** → re-run all validators. Honour cross-room
constraints as they come online (Overlook/Choir shaft alignment §2.1; every opening against the
neighbour's *frozen* geometry, not just the new room's own mask).

- **Step 3a — the Cistern's fifth opening (the one approved frozen-geometry edit, §9 C1).** Carve
  the shortcut's landing stub into `room_a.json` and add the `from_threshold` entry, under its own
  owner sign-off and re-freeze, **preserving the M5 reference-still read**. Do this alongside
  Threshold (the shortcut's other end) so both faces of the one-way link land together. Then wire
  the shortcut edge that Step 2 deliberately left out. Re-run every Cistern-touching check.

**Step 4 — Finalize content per room.** Chimes beside their doors, pickups on floor outside
reserved zones, sealed doors, boss-station markers. Re-validate the whole map.

**Step 5 — The play-through gate (§1.1).** A stranger plays Hollow → boss unprompted. Record what
they did in `docs/m7-progress.md`. **Not waived.**

**Step 6 — Close M7.** Write `docs/m7-progress.md`; trim CLAUDE.md §2/§8 and README to
M7-done / M8-next (the "trim, don't append" rule, §12); retire `docs/m5-progress.md` if nothing
downstream still leans on it.

---

## 7. Verification (run after every room change)

```
godot --headless --import                                          # parse check, first
godot --headless --script tests/test_melody_matcher.gd             # 32
godot --headless --script tests/test_instrument_keyboard_layout.gd # 21
godot --headless --script tests/test_rock_bevel.gd                 # 23
godot --headless --script tests/test_door_layout.gd                # 12
godot --headless --script tests/test_room_geometry.gd              # 16
# + new: ability-gate validator tests, room_link ability-gate test
python3 scripts/validate_rooms.py                                  # graph + ramp + ability gates
python3 scripts/seal_test.py                                       # door seals (+ non-reciprocal edge)
python3 scripts/lint_rooms.py                                      # per-room geometry
python3 scripts/test_lint_rooms.py                                 # lint fixtures
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . \
  | grep -vE '^\./(tests|scripts/music/note_names)'                # §3 one-rule: must be empty
```

Plus the colour corollary (no hex in a scene/script; unknown palette names return magenta), and
the owner's `godot .` sign-off per frozen room.

---

## 8. Components touched (isolation view)

| Unit | Change | Depends on |
|---|---|---|
| `data/rooms.json` | full eleven-room graph rewrite | notes, melodies, room files |
| `data/rooms/room_*.json` (×9 new) | new room geometry + content | `roomlib` maths |
| `data/rooms/room_a.json` | `display_name` fix; **carve 5th opening/stub + `from_threshold` entry** (§9 C1, the one approved frozen-geometry edit, Step 3a) | roomlib; M5 still |
| `data/rooms/room_b.json` | remove `n_mend` pickup; `display_name` | locked geometry |
| `data/melodies/door_b|c|omega.json` | new placeholder melodies | notes.json |
| `scripts/validate_rooms.py` | ability-gate reachability + integrity; ramp skip | pure, CI |
| `scripts/roomlib.py` / `lint_rooms.py` | ability-gate = ordinary link (likely no change) | — |
| `scripts/seal_test.py` | tolerate non-reciprocal edge (likely no change) | roomlib |
| `objects/room_link.gd` | ability-gate ownership gate | `NoteInventory` |
| `scenes/rooms/room_content.gd` | instance sealed doors / station markers as needed | EnvPalette |
| `scripts/new_room.py` (new) | scaffold | roomlib |
| `world.gd` / `main.gd` | debug `--room=` jump flag | — |
| `tests/` | ability-gate coverage | — |

---

## 9. Open conflicts and decisions — resolve before Step 3 (owner's calls)

These must not be settled inside a room build.

- **C1 — the one-way shortcut's Cistern landing — RESOLVED (owner, 2026-09-22).** The frozen
  Cistern has exactly four perimeter openings, all assigned: N cols 23–24 (Door Ω), E rows 13–14
  (Door A), W rows 26–27 (Hollow free gap), S cols 33–34 (5-gem sealed door) — no free slot for
  the shortcut. **Resolution: add a fifth opening/stub to the Cistern** for the `from_threshold`
  landing. This is the single approved edit to frozen M5 geometry (§1.2): carved in Step 3a with
  owner sign-off, re-frozen, and it **must preserve the M5 reference-still read**
  (`docs/m5-reference/cistern-final.png`) — placement to be chosen at the carve, 2 tiles wide with
  an apron ≥ 4, clear of the four existing openings' footprints and the 5-gem door, height-matched
  to Threshold's shortcut-side opening. Re-run every Cistern-touching check and re-capture/confirm
  the still. Rejected alternatives: re-routing the shortcut off the Cistern (a map change), and
  sharing an existing opening (a muddier read).
- **D1 — sealed exits as content vs. graph edges (§3.2).** This spec uses `sealed_doors` content
  (no new schema). Confirm, or require null-target graph edges instead.
- **D2 — the shortcut modelled as a non-reciprocal free edge + decorative art (§3.3).** Confirm.
- **D3 — `room_c` / `room_d` retired (deleted).** Confirm deletion vs. repurpose.
- **D4 — pipeline scope:** build `new_room.py` + `--room=` jump now; defer the preview tool.
  Confirm.
- **D5 — the Choir's sealed east passage** leads nowhere in Act 1 (decorative). Confirm it needs
  no Act-2 target yet.
- **Deferred, not this milestone (design doc §9):** which pitch classes map to which category
  (three assigned, all the map needs); five-note demo; note ability behaviours; boss mechanics;
  the convergent finale.

---

## 10. Known staleness to fix on close

- CLAUDE.md §2/§8 and README describe M7 as "not yet spec'd"; update to point at this spec and
  then to M7-done / M8-next at Step 6.
- The Master Design Document (Drive) still describes an earlier milestone as current; CLAUDE.md and
  `docs/m6-progress.md` are the build-state authority until the design doc gets another pass.
