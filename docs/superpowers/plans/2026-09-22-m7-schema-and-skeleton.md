# M7 Schema & Skeleton-Graph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land M7's code spine — the ability-gate schema, the authoring pipeline, and the full eleven-room grey-box graph — so the whole Act 1 map is connected, gated, and provably solvable/walkable end-to-end before any room is carved to its archetype.

**Architecture:** Skeleton-first (spec §6). Add the one genuinely new data contract (ability-gate edges) across all four consumers — the Python validator, the room lint, the in-engine `RoomGraph` boot check, and the runtime room builder — with the pure Python parts driven by unit tests and the GDScript parts verified by headless boot + a manual walk (the autoload-compile trap means gate nodes can't run under `--script`). Then rewrite `data/rooms.json` to the real graph and stand up nine minimal grey-box rooms so `validate_rooms` + `seal_test` + `lint_rooms` + the boot check + a manual playthrough are all green. Carving rooms to their archetypes (spec §5, Steps 3–6) is a separate authoring phase — see "Scope & Follow-on" at the end.

**Tech Stack:** Godot 4.7.2 / GDScript (static types); standalone Python 3.12 (stdlib only) for `validate_rooms.py` / `lint_rooms.py` / `seal_test.py` / `roomlib.py`; JSON data under `data/`.

**Spec:** `docs/superpowers/specs/2026-09-22-m7-greybox-map-design.md` (read it alongside this plan).

## Global Constraints

- **The one rule (spec §3, CLAUDE.md §3):** no pitch, melody, or musical pattern in any `.gd` file. Code refers to notes/melodies by **id**. Pitch literals live only in `data/` (JSON) and in `tests/` / `note_names.gd`. The grep `grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'` must return nothing.
- **No hex colour in a scene or script.** Colours resolve by name through `EnvPalette`; an unknown name returns magenta (CLAUDE.md §4).
- **`requires` mirrors `door`:** an ability-gate edge's `{ "note": <id> }` appears in **both** `data/rooms.json` (the graph exit, read by `validate_rooms.py` + `RoomGraph`) **and** `data/rooms/<id>.json` (the geometry link, read by `room.gd`). An exit/link carries **at most one** of `door` / `requires`.
- **Ability-gate passability = ownership of the note id** (`requires.note in collected` for the validator; `NoteInventory.has(required_note)` in-engine). Note abilities themselves (the visible jump/mend) are M11 and out of scope.
- **Grey-box only:** no light (M8), detail (M9), door presentation (M10), boss mechanics (M12), audio (M13).
- **Melodies stay `placeholder: true`** and use only the pitch classes owned when the door is first reached (Door A ⊆ {C}; Door B ⊆ {C,E}; Doors C/Ω ⊆ {C,D,E}).
- **Commits:** small, behaviour-describing messages. **No `Co-Authored-By: Claude` trailer** in any repo under `~/Code/Projects` (CLAUDE.md commit-convention override). Do not re-add `CLAUDE.md` to git (it is intentionally gitignored).
- **Files stay ~200 lines;** static types on every func; snake_case members/files, PascalCase classes/nodes.
- **Scene-file caution:** if you edit a `.tscn` that is open in the Godot editor, say so — the owner must close/reopen that tab or their next save reverts it. Scripts reload cleanly.

**Notes owned along the critical path** (fixed inputs for melodies and gates): `n_break` (C, destructive) in the Hollow → `n_step` (E, movement) in the Drip → `n_mend` (D, restorative) in the Choir.

---

## Task A1: `validate_rooms.py` — pure `validate()` + ability-gate reachability

**Files:**
- Modify: `scripts/validate_rooms.py` (extract a pure entry point; add `requires` handling)
- Create: `scripts/test_validate_rooms.py`

**Interfaces:**
- Produces: `validate(rooms: dict, notes: dict, melodies: dict) -> tuple[list[str], list[str]]` returning `(errors, warnings)`. `rooms` is the `{start, rooms}` graph dict; `notes` maps id→record; `melodies` maps id→record. `main()` loads the files and calls it.
- Consumes (unchanged helpers): `pitch_class`, `SEMITONE`, `ramp_ceiling`.

- [ ] **Step 1: Write the failing tests**

```python
# scripts/test_validate_rooms.py
import unittest
from validate_rooms import validate

NOTES = {
    "n_break": {"id": "n_break", "pitch_class": "C", "category": "destructive", "index": 0},
    "n_step":  {"id": "n_step",  "pitch_class": "E", "category": "movement",    "index": 0},
}
MEL = {"d1": {"id": "d1", "notes": ["C4"]}}  # 1-note door, needs C


def graph(exits_drip):
    # hollow(note C) -> drip(note E) -> overlook, with the drip->overlook exit under test
    return {
        "start": {"room": "hollow", "entry": "spawn"},
        "rooms": {
            "hollow":   {"notes": ["n_break"], "entries": ["spawn"],
                         "exits": [{"to": "drip", "to_entry": "from_hollow"}]},
            "drip":     {"notes": ["n_step"], "entries": ["from_hollow", "from_overlook"],
                         "exits": exits_drip},
            "overlook": {"notes": [], "entries": ["from_drip"], "exits": []},
        },
    }


class AbilityGate(unittest.TestCase):
    def test_passable_when_note_owned(self):
        # drip holds n_step, gate requires n_step -> overlook reachable, no errors
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_step"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertEqual(errors, [])

    def test_unreachable_when_note_missing(self):
        # gate requires a note found nowhere -> overlook unreachable -> error
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_mend"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("overlook" in e and "unreachable" in e for e in errors))

    def test_unknown_required_note_errors(self):
        g = graph([{"to": "overlook", "to_entry": "from_drip", "requires": {"note": "n_bogus"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("n_bogus" in e for e in errors))

    def test_door_and_requires_on_one_exit_errors(self):
        g = graph([{"to": "overlook", "to_entry": "from_drip",
                    "door": "d1", "requires": {"note": "n_step"}}])
        errors, _ = validate(g, NOTES, MEL)
        self.assertTrue(any("both" in e.lower() for e in errors))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd scripts && python3 -m pytest test_validate_rooms.py -q` (or `python3 test_validate_rooms.py`)
Expected: FAIL — `ImportError: cannot import name 'validate'`.

- [ ] **Step 3: Extract `validate()` and add the `requires` branch**

Refactor the body of `main()` into `validate(rooms, notes, melodies)` returning `(errors, warnings)`; `main()` loads the JSON and calls it, keeping its current printing/exit behaviour. In the reachability fixpoint, replace the door-only passability with:

```python
door = str(ex.get("door", ""))
req = ex.get("requires")
if door and req is not None:
    errors.append(f"room '{rid}' exit to '{ex.get('to','')}' has both a door and a requires")
    passable = False
elif req is not None:
    need_id = str(req.get("note", ""))
    if need_id not in notes:
        errors.append(f"room '{rid}' ability gate names unknown note '{need_id}'")
        passable = False
    else:
        passable = need_id in collected        # ownership by id, mirrors NoteInventory.has
elif door:
    need = melody_pcs(door)                      # existing melody-door logic, unchanged
    passable = (need is not None) and (need <= owned)
    if passable and door not in door_opened_at:
        door_opened_at[door] = len(collected)
else:
    passable = True
```

Keep the existing referential-integrity loop; add there: if an exit has `requires`, assert `requires.note` resolves in `notes` (so a bad id errors even on an unreachable branch).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd scripts && python3 test_validate_rooms.py`
Expected: PASS (4 tests). Then `python3 scripts/validate_rooms.py` still prints OK for the current data.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate_rooms.py scripts/test_validate_rooms.py
git commit -m "Add ability-gate reachability to the room validator"
```

---

## Task A2: `lint_rooms.py` — reserve ability-gate footprints

**Files:**
- Modify: `scripts/lint_rooms.py` (the footprint-reservation condition)
- Modify: `scripts/test_lint_rooms.py` (add two fixtures)

**Interfaces:**
- Consumes: `roomlib.door_rect`, `roomlib.inward` (unchanged); `lint_room(data) -> (errors, warnings)`.

- [ ] **Step 1: Write the failing fixtures**

Add to `scripts/test_lint_rooms.py` a room dict with a `requires` link whose leaf footprint holds a prop, and its clean twin:

```python
def _gate_room(prop_at):
    # 12-wide x 6-tall, a 2-tile east opening at rows 2-3 with an ability gate
    grid = ["############"] * 6
    grid[2] = "###########."   # col 11 (east edge) floor
    grid[3] = "###########."
    # carve floor inward so the opening + apron are floor
    grid = [list(r) for r in grid]
    for y in (2, 3):
        for x in range(4, 12):
            grid[y][x] = "."
    grid = ["".join(r) for r in grid]
    return {
        "room_id": "gate_fixture", "size_tiles": [12, 6], "grid": grid,
        "entries": {"from_east": [11, 2]},
        "links": [{"at": [11, 2], "to_room": "x", "to_entry": "from_gate",
                   "requires": {"note": "n_step"}}],
        "pickups": [], "chimes": [], "props": [{"at": list(prop_at)}],
    }


class AbilityGateFootprint(unittest.TestCase):
    def test_prop_in_gate_footprint_errors(self):
        # a prop right at the leaf (1.5 tiles in from col 11, rows 2-3) is reserved
        errors, _ = lint_room(_gate_room((9, 2)))
        self.assertTrue(any("reserved footprint" in e for e in errors))

    def test_prop_clear_of_gate_ok(self):
        errors, _ = lint_room(_gate_room((5, 2)))
        self.assertEqual([e for e in errors if "reserved footprint" in e], [])
```

- [ ] **Step 2: Run to verify the first fails**

Run: `cd scripts && python3 test_lint_rooms.py`
Expected: FAIL on `test_prop_in_gate_footprint_errors` — a `requires` link currently reserves nothing, so no error is raised.

- [ ] **Step 3: Extend the reservation condition**

In `lint_rooms.py`, the footprint loop currently skips a link unless it has `door`/`melody_id`/`sockets`. Make a `requires` link reserve its leaf too:

```python
for d in list(data.get("links", [])) + list(data.get("sealed_doors", [])):
    at = tuple(d.get("at", [0, 0]))
    inw = roomlib.inward(at, cols, rows)
    has_leaf = d.get("door") is not None or "melody_id" in d or "sockets" in d or d.get("requires") is not None
    if inw == (0, 0) or not has_leaf:
        continue  # a plain (free) link reserves nothing
    name = d.get("door") or ("ability gate" if d.get("requires") else "sealed_door")
    ...
```

Leave the entry-landing inset for `requires` links using `DOOR_ENTRY_INSET` as well (they carry a blocking leaf): update line ~103 to `inset = roomlib.DOOR_ENTRY_INSET if (link.get("door") or link.get("requires")) else float(roomlib.ENTRY_INSET)`.

- [ ] **Step 4: Run to verify both pass**

Run: `cd scripts && python3 test_lint_rooms.py`
Expected: PASS (existing 12 + 2 new). Then `python3 scripts/lint_rooms.py` still prints per-room results with no new errors on existing rooms.

- [ ] **Step 5: Commit**

```bash
git add scripts/lint_rooms.py scripts/test_lint_rooms.py
git commit -m "Reserve ability-gate leaf footprints in the room lint"
```

---

## Task A3: `scripts/new_room.py` — the room scaffold

**Files:**
- Create: `scripts/new_room.py`
- Create: `scripts/test_new_room.py`

**Interfaces:**
- Produces: `scaffold(room_id: str, cols: int, rows: int) -> dict` — a room-geometry dict that is `lint_rooms.lint_room`-clean (zero errors; a rock warning is fine). `main(argv)` writes it to `data/rooms/<id>.json` if absent.

- [ ] **Step 1: Write the failing test**

```python
# scripts/test_new_room.py
import unittest
from new_room import scaffold
from lint_rooms import lint_room


class Scaffold(unittest.TestCase):
    def test_scaffold_is_lint_clean(self):
        data = scaffold("room_probe", 32, 18)
        self.assertEqual(data["size_tiles"], [32, 18])
        errors, _ = lint_room(data)
        self.assertEqual(errors, [])           # warnings (rock %) allowed

    def test_scaffold_has_spawn_on_floor(self):
        data = scaffold("room_probe", 20, 12)
        sx, sy = data["entries"]["spawn"]
        self.assertEqual(data["grid"][sy][sx], ".")
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd scripts && python3 test_new_room.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'new_room'`.

- [ ] **Step 3: Implement the scaffold**

Solid rock with a small central floor pocket for `spawn`, no links (so no opening/apron rules apply yet):

```python
#!/usr/bin/env python3
"""Scaffold a lint-green solid-rock room to carve from (spec §6 Step 0)."""
from __future__ import annotations
import json, sys
from pathlib import Path
import roomlib

def scaffold(room_id: str, cols: int, rows: int) -> dict:
    grid = [["#"] * cols for _ in range(rows)]
    cx, cy = cols // 2, rows // 2
    for y in range(cy - 1, cy + 1):
        for x in range(cx - 1, cx + 1):
            grid[y][x] = "."
    return {
        "room_id": room_id,
        "size_tiles": [cols, rows],
        "grid": ["".join(r) for r in grid],
        "entries": {"spawn": [cx, cy]},
        "links": [], "pickups": [], "chimes": [], "sealed_doors": [], "props": [],
    }

def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: new_room.py <room_id> <cols> <rows>", file=sys.stderr)
        return 2
    room_id, cols, rows = argv[0], int(argv[1]), int(argv[2])
    path = roomlib.ROOMS_DIR / f"{room_id}.json"
    if path.exists():
        print(f"{path} already exists", file=sys.stderr)
        return 1
    path.write_text(json.dumps(scaffold(room_id, cols, rows), indent=2) + "\n", encoding="utf-8")
    print(f"wrote {path}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd scripts && python3 test_new_room.py`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/new_room.py scripts/test_new_room.py
git commit -m "Add new_room.py room scaffold"
```

---

## Task A4: `AbilityGate` node

**Files:**
- Create: `scenes/objects/ability_gate.gd`

**Interfaces:**
- Produces: `class_name AbilityGate extends Node2D` with `@export var required_note: String`, `@export var facing: Vector2i`, `@export var slab_size: Vector2`. Blocks passage (a `StaticBody2D` leaf) until `NoteInventory.has(required_note)`, then disables the blocker.
- Consumes: `NoteInventory` autoload (`has`, `note_collected`).

**Note on testing:** this node references the `NoteInventory` autoload, so it cannot compile under `--script` (the autoload-compile trap — see the project memory). It is verified by `godot --headless --import` (parse) and the manual walk in Task A8, not a unit test. Keep the *logic* trivial so there is nothing to unit-test: ownership → open.

- [ ] **Step 1: Write the node**

```gdscript
class_name AbilityGate
extends Node2D
## A note-gated passage (spec §3.1). A physical blocker over an opening or an internal
## corridor that lifts the instant the player owns `required_note` — the grey-box stand-in
## for the note ability that will animate the crossing in M11. Ownership is the source of
## truth (NoteInventory is an autoload that persists across room re-instancing), so unlike a
## melody Door this needs no WorldState: it just re-checks `has()` on _ready.
##
## No `space` interaction and no melody: it is not an Interactable. It opens on ownership.

@export var required_note: String = ""
## Into the room, like room.gd's `inward`. Reserved for M10 art orientation; unused in grey-box.
@export var facing: Vector2i = Vector2i(0, 1)
@export var slab_size: Vector2 = Vector2(72.0, 90.0)

var _blocker: CollisionShape2D


func _ready() -> void:
	_add_blocker()
	if NoteInventory.has(required_note):
		_open()
	else:
		NoteInventory.note_collected.connect(_on_note_collected)


func _on_note_collected(note_id: String) -> void:
	if note_id == required_note:
		_open()


func _open() -> void:
	if _blocker != null:
		_blocker.set_deferred("disabled", true)


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	_blocker = CollisionShape2D.new()
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)
```

- [ ] **Step 2: Parse-check**

Run: `godot --headless --import`
Expected: no parse errors for `ability_gate.gd`.

- [ ] **Step 3: Verify the one-rule grep is still clean**

Run: `grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'`
Expected: empty.

- [ ] **Step 4: Commit**

```bash
git add scenes/objects/ability_gate.gd
git commit -m "Add AbilityGate node: a note-ownership-gated passage"
```

---

## Task A5: Wire `requires` in `room.gd` / `RoomContent`

**Files:**
- Modify: `scenes/rooms/room.gd` (`_build_links`, `_record_entries`)
- Modify: `scenes/rooms/room_content.gd` (add `build_ability_gate`, and an internal `build_ability_gates` from a content array for the Span fissure)

**Interfaces:**
- Consumes: `AbilityGate` (Task A4), `RoomGeometry` (`inward`, `inset_point`, `DOOR_INSET`, `DOOR_ENTRY_INSET`, `ENTRY_INSET`).
- Produces: an `AbilityGate` child per `requires` link and per `ability_gates` content entry; entry landings for `requires` links use `DOOR_ENTRY_INSET`.

**Modeling note (records a spec §4.2 refinement):** the **Drip→Overlook** gate is an inter-room boundary → a `requires` **link** (built here). The **Span fissure** is *internal* and sits behind Door C (whose melody already needs note 3), so it is an `ability_gates` **content** entry `{ "at": [c,r], "note": "n_mend", "facing": [dx,dy] }`, not an edge; the validator's Span solvability is carried by Door C. Both render with `AbilityGate`.

- [ ] **Step 1: Add the content builders**

In `room_content.gd`:

```gdscript
## An inter-room ability gate: the leaf of a `requires` link, placed like a door leaf.
static func build_ability_gate(parent: Node2D, geom: RoomGeometry, note_id: String, link_at: Vector2i, inward: Vector2i) -> void:
	var gate := AbilityGate.new()
	gate.required_note = note_id
	gate.facing = inward
	gate.position = geom.inset_point(link_at, inward, RoomGeometry.DOOR_INSET)
	parent.add_child(gate)


## Internal ability gates (e.g. the Span fissure): a blocker inside the room, not on an edge.
static func build_ability_gates(parent: Node2D, geom: RoomGeometry, defs: Array) -> void:
	for d in defs:
		var gate := AbilityGate.new()
		gate.required_note = str(d.get("note", ""))
		gate.facing = RoomGeometry.to_v2i(d.get("facing", [0, 1]))
		gate.position = geom.cell_center(RoomGeometry.to_v2i(d.get("at", [0, 0])))
		parent.add_child(gate)
```

- [ ] **Step 2: Wire links + internal gates + entry inset in `room.gd`**

In `_build_links`, after building the `RoomLink`, add the ability-gate leaf when the link declares `requires`:

```gdscript
var door_id := str(link_def.get("door", ""))
if not door_id.is_empty():
	RoomContent.build_door(self, _geom, door_id, at, inward)
else:
	var req: Dictionary = link_def.get("requires", {})
	var req_note := str(req.get("note", ""))
	if not req_note.is_empty():
		RoomContent.build_ability_gate(self, _geom, req_note, at, inward)
```

In `_record_entries`, treat a `requires` link like a doored one for the landing inset:

```gdscript
var has_leaf := not str(link.get("door", "")).is_empty() or not (link.get("requires", {}) as Dictionary).is_empty()
var inset := RoomGeometry.DOOR_ENTRY_INSET if has_leaf else float(RoomGeometry.ENTRY_INSET)
```

In `_ready`, instance internal gates alongside the other content:

```gdscript
RoomContent.build_ability_gates(self, _geom, geo.get("ability_gates", []))
```

- [ ] **Step 3: Parse-check + boot**

Run: `godot --headless --import` then `godot --headless --script tests/test_room_geometry.gd`
Expected: no parse errors; the 16 geometry tests still pass (this task touches no `RoomGeometry` maths).

- [ ] **Step 4: Commit**

```bash
git add scenes/rooms/room.gd scenes/rooms/room_content.gd
git commit -m "Build ability gates from requires links and internal ability_gates"
```

---

## Task A6: `RoomGraph` boot check — validate & match `requires`

**Files:**
- Modify: `autoload/room_graph.gd` (`_check_room`, `_link_matches`, and the `exits()` doc comment)

**Interfaces:**
- Consumes: `NoteRegistry.by_id` (already used for note validation).

- [ ] **Step 1: Validate the required note and forbid door+requires**

In `_check_room`, inside the exits loop, after the existing `door` melody check:

```gdscript
var req: Dictionary = exit.get("requires", {})
if not req.is_empty():
	if not door.is_empty():
		push_error("RoomGraph[%s]: exit %s has both a door and a requires." % [room_id, exit])
	var req_note := str(req.get("note", ""))
	if NoteRegistry.by_id(req_note).is_empty():
		push_error("RoomGraph[%s]: ability gate names unknown note '%s'." % [room_id, req_note])
```

- [ ] **Step 2: Match `requires` between graph exit and geometry link**

Extend `_link_matches` so a graph exit's `requires.note` must equal its geometry link's:

```gdscript
func _link_matches(links: Array, exit: Dictionary) -> bool:
	for link in links:
		if (
			str(link.get("to_room", "")) == str(exit.get("to", ""))
			and str(link.get("to_entry", "")) == str(exit.get("to_entry", ""))
			and str(link.get("door", "")) == str(exit.get("door", ""))
			and str((link.get("requires", {}) as Dictionary).get("note", "")) == str((exit.get("requires", {}) as Dictionary).get("note", ""))
		):
			return true
	return false
```

Update the `exits()` doc comment to `[{to, to_entry, door?, requires?}]`.

- [ ] **Step 3: Boot-check**

Run: `godot --headless --import` then `godot .` briefly (watch stdout)
Expected: no new `RoomGraph[...]` errors on the current data (which has no `requires` yet — proves the additions are inert until used).

- [ ] **Step 4: Commit**

```bash
git add autoload/room_graph.gd
git commit -m "Cross-check ability-gate requires in the RoomGraph boot check"
```

---

## Task A7: Placeholder door melodies B, C, Ω

**Files:**
- Create: `data/melodies/door_b.json`, `data/melodies/door_c.json`, `data/melodies/door_omega.json`

**Interfaces:**
- Consumed by: `data/rooms.json` gates (Task A8) and `validate_rooms.py` ramp/solvability.

- [ ] **Step 1: Write the three melodies (within the owned pitch classes)**

`door_b.json` (2 notes, ⊆ {C,E}); `door_c.json` (3 notes, ⊆ {C,D,E}); `door_omega.json` (3 notes, ⊆ {C,D,E}). All mirror `door_tutorial`'s shape:

```json
{
  "id": "door_b",
  "display_name": "Choir Door",
  "notes": ["C4", "E4"],
  "rhythm": [1, 1],
  "key": "C", "mode": "major", "tempo_bpm": 90,
  "match_rules": { "order_matters": true, "timing_matters": false, "octave_matters": false, "allow_transposition": false },
  "finale_role": "unassigned",
  "placeholder": true
}
```

`door_c`: `"notes": ["E4", "C4", "D4"]`, `"rhythm": [1, 1, 1]`. `door_omega`: `"notes": ["D4", "E4", "C4"]`, `"rhythm": [1, 1, 1]`. (Exact pitches are placeholders the owner recomposes; only the pitch-class *set* and length are load-bearing.)

- [ ] **Step 2: Verify they load and match-test still passes**

Run: `godot --headless --import` then `godot --headless --script tests/test_melody_matcher.gd`
Expected: import clean; 32 matcher tests pass (they assert on fixtures, not these files).

- [ ] **Step 3: Commit**

```bash
git add data/melodies/door_b.json data/melodies/door_c.json data/melodies/door_omega.json
git commit -m "Add placeholder melodies for Doors B, C and Omega"
```

---

## Task A8: The skeleton graph — real `rooms.json` + nine grey-box rooms

This is the integration task: the map becomes connected, gated and solvable. Its "test" is the full green bar (validators + boot + a manual walk), not a unit test. Do it in small commits.

**Files:**
- Rewrite: `data/rooms.json` (the eleven-room graph)
- Create (via `new_room.py`, then carve minimal openings): `data/rooms/room_hollow.json`, `room_drip.json`, `room_overlook.json`, `room_stair.json`, `room_choir.json`, `room_span.json`, `room_threshold.json`, `room_antechamber.json`, `room_resonance.json`
- Delete: `data/rooms/room_c.json`, `data/rooms/room_d.json`
- Modify: `data/rooms/room_a.json` (`display_name` → "Cistern"; the `from_threshold` entry and 5th opening are **deferred to the carving phase / Step 3a**, so the shortcut edge is left out here), `data/rooms/room_b.json` (`display_name` → "Gallery"; remove the `n_mend` pickup)

**Interfaces:**
- Consumes: ability-gate schema (A1–A6), scaffold (A3), melodies (A7).
- Produces: a graph where `validate_rooms` + `seal_test` + `lint_rooms` + the boot check pass and the map is walkable Hollow → boss (minus the shortcut, wired in the carving phase).

- [ ] **Step 1: Scaffold the nine rooms at their spec §5 sizes**

Run (screens × 32×18):
```bash
cd /Users/jayden/Code/Projects/resonance
python3 scripts/new_room.py room_hollow 32 18
python3 scripts/new_room.py room_drip 32 18
python3 scripts/new_room.py room_overlook 32 18
python3 scripts/new_room.py room_stair 32 54
python3 scripts/new_room.py room_choir 96 36
python3 scripts/new_room.py room_span 64 18
python3 scripts/new_room.py room_threshold 32 18
python3 scripts/new_room.py room_antechamber 32 18
python3 scripts/new_room.py room_resonance 64 36
```
Expected: nine `wrote data/rooms/<id>.json` lines. `python3 scripts/lint_rooms.py` shows each new room error-free (rock warnings expected).

- [ ] **Step 2: Carve minimal mirrored openings + landings in each room**

For each edge in the graph (Step 3), open a **2-tile** perimeter gap on both sides at the **same height**, with a ≥4-tile straight apron, and add the matching `from_<room>` entry one tile inside (`lint_rooms` derives and checks the landing). Place the three pickups (`n_break`→Hollow, `n_step`→Drip, `n_mend`→Choir), the internal Span `ability_gates` entry, chimes (Door A hub chime already in `room_a`; a Stair chime for Door B; three fragment chimes for Door Ω across three rooms), and the Choir/Resonance sealed doors. Skeleton interiors stay near-solid — only the openings, aprons, and content cells are carved. Run `python3 scripts/lint_rooms.py <id>` after each room until error-free.

- [ ] **Step 3: Rewrite `data/rooms.json` to the eleven-room graph**

Structure (gates per spec §4.2; the shortcut edge is intentionally omitted until Step 3a of the carving phase):

```json
{
  "start": { "room": "room_hollow", "entry": "spawn" },
  "rooms": {
    "room_hollow":      { "display_name": "Hollow", "notes": ["n_break"], "entries": ["spawn", "from_cistern"],
                          "exits": [ { "to": "room_a", "to_entry": "from_hollow" } ] },
    "room_a":           { "display_name": "Cistern", "notes": [], "entries": ["spawn", "from_hollow", "from_gallery", "from_antechamber"],
                          "exits": [ { "to": "room_hollow", "to_entry": "from_cistern" },
                                     { "to": "room_b", "to_entry": "from_a", "door": "door_tutorial" },
                                     { "to": "room_antechamber", "to_entry": "from_cistern", "door": "door_omega" } ] },
    "room_b":           { "display_name": "Gallery", "notes": [], "entries": ["from_a", "from_drip"],
                          "exits": [ { "to": "room_a", "to_entry": "from_gallery" },
                                     { "to": "room_drip", "to_entry": "from_gallery" } ] },
    "room_drip":        { "display_name": "Drip chamber", "notes": ["n_step"], "entries": ["from_gallery", "from_overlook"],
                          "exits": [ { "to": "room_b", "to_entry": "from_drip" },
                                     { "to": "room_overlook", "to_entry": "from_drip", "requires": { "note": "n_step" } } ] },
    "room_overlook":    { "display_name": "Overlook", "notes": [], "entries": ["from_drip", "from_stair"],
                          "exits": [ { "to": "room_drip", "to_entry": "from_overlook" },
                                     { "to": "room_stair", "to_entry": "from_overlook" } ] },
    "room_stair":       { "display_name": "The Stair", "notes": [], "entries": ["from_overlook", "from_choir"],
                          "exits": [ { "to": "room_overlook", "to_entry": "from_stair" },
                                     { "to": "room_choir", "to_entry": "from_stair", "door": "door_b" } ] },
    "room_choir":       { "display_name": "The Choir", "notes": ["n_mend"], "entries": ["from_stair", "from_span"],
                          "exits": [ { "to": "room_stair", "to_entry": "from_choir" },
                                     { "to": "room_span", "to_entry": "from_choir" } ] },
    "room_span":        { "display_name": "The Span", "notes": [], "entries": ["from_choir", "from_threshold"],
                          "exits": [ { "to": "room_choir", "to_entry": "from_span" },
                                     { "to": "room_threshold", "to_entry": "from_span", "door": "door_c" } ] },
    "room_threshold":   { "display_name": "Threshold", "notes": [], "entries": ["from_span"],
                          "exits": [ { "to": "room_span", "to_entry": "from_threshold" } ] },
    "room_antechamber": { "display_name": "Antechamber", "notes": [], "entries": ["from_cistern", "from_resonance"],
                          "exits": [ { "to": "room_a", "to_entry": "from_antechamber" },
                                     { "to": "room_resonance", "to_entry": "from_antechamber" } ] },
    "room_resonance":   { "display_name": "Resonance chamber", "notes": [], "entries": ["from_antechamber"],
                          "exits": [ { "to": "room_antechamber", "to_entry": "from_resonance" } ] }
  }
}
```

Then delete `data/rooms/room_c.json` and `data/rooms/room_d.json`.

- [ ] **Step 4: Run the full green bar**

```bash
godot --headless --import
python3 scripts/validate_rooms.py     # 10 rooms reachable (11th, the boss onward, is a sealed content door), doors solvable, ramp holds
python3 scripts/seal_test.py          # room_a doors still seal (unchanged)
python3 scripts/lint_rooms.py         # every room error-free
python3 scripts/test_validate_rooms.py && (cd scripts && python3 test_lint_rooms.py && python3 test_new_room.py)
godot --headless --script tests/test_melody_matcher.gd
godot --headless --script tests/test_instrument_keyboard_layout.gd
godot --headless --script tests/test_rock_bevel.gd
godot --headless --script tests/test_door_layout.gd
godot --headless --script tests/test_room_geometry.gd
grep -rnE '"[A-G](#|b)?[0-9]"' --include=*.gd . | grep -vE '^\./(tests|scripts/music/note_names)'   # empty
```
Expected: all green; grep empty. If `validate_rooms` reports a ramp warning or an unreachable room, fix the offending melody/opening before proceeding.

- [ ] **Step 5: Manual walk (owner or Claude on `godot .`)**

Run: `godot .` and walk Hollow → Cistern → Door A → Gallery → Drip → (own note 2) Overlook → Stair → Door B → Choir → Span → Door C → Threshold. (The Threshold→Cistern shortcut and the Cistern→Antechamber→Resonance leg light up once Step 3a carves the Cistern's fifth opening in the carving phase.) Use `godot . -- --room=<id>` if the debug jump from the follow-on pipeline task is in.
Expected: every transition lands at the mirrored height; every door/gate blocks until satisfied then opens.

- [ ] **Step 6: Commit**

```bash
git add data/rooms.json data/rooms/room_hollow.json data/rooms/room_drip.json \
        data/rooms/room_overlook.json data/rooms/room_stair.json data/rooms/room_choir.json \
        data/rooms/room_span.json data/rooms/room_threshold.json data/rooms/room_antechamber.json \
        data/rooms/room_resonance.json data/rooms/room_a.json data/rooms/room_b.json
git rm data/rooms/room_c.json data/rooms/room_d.json
git commit -m "Wire the eleven-room skeleton graph with gates and grey-box rooms"
```

---

## Self-Review

- **Spec coverage:** §3.1 ability-gate edges → A1/A2/A4/A5/A6; §3.2 sealed exits (existing content) → A8 Step 2; §3.3 one-way shortcut modelling → A6/A8 (edge omitted here, carved in the follow-on Step 3a); §4.1 ids/retire/start → A8; §4.2 gates/melodies → A7/A8; §4.3 pickups/chimes → A8; §6 Steps 0–2 → A1–A8. Steps 3–6 (room carving, playthrough gate, closeout) are the follow-on phase below — intentionally not in this plan.
- **Placeholder scan:** none — every step carries real code or exact data.
- **Type consistency:** `requires: { note }` used identically in the validator (`requires.note in collected`), lint (`d.get("requires")`), `room.gd`/`RoomContent` (`build_ability_gate(note_id, at, inward)`), and `RoomGraph` (`requires.note`). `AbilityGate.required_note` matches the builder's argument. Melody ids `door_b/door_c/door_omega` match between A7 and the A8 graph.

---

## Scope & Follow-on (not in this plan)

This plan delivers spec Steps 0–2: a validated, walkable grey-box map. The remaining M7 work is a **room-authoring phase** that does not fit a pre-written TDD plan — each room gates on `lint_rooms` **plus the owner's `godot .` sign-off and a freeze**, per `docs/room-authoring.md`:

- **Step 3 — carve each room to its archetype** (spec §5), one at a time in play order, Hollow first.
- **Step 3a — the Cistern's fifth opening** (the one approved frozen-geometry edit, spec §9 C1): carve the shortcut landing + `from_threshold` entry, re-freeze, preserve the M5 still; then add the shortcut edge to `data/rooms.json` and `room_threshold.json`.
- **Step 4 — finalize content**, then **Step 5 — the stranger playthrough gate** (do **not** waive), then **Step 6 — close M7** (write `docs/m7-progress.md`; trim CLAUDE.md §2/§8 + README).
- **Pipeline:** the `--room=<id>` debug jump (spec §6 Step 0) is small engine wiring best landed at the start of the carving phase, when room-hopping review begins to pay off.

Recommend generating a per-room authoring plan (or running the recipe directly) once this skeleton is green.
