#!/usr/bin/env python3
"""Solvability validator for the room graph (spec §7, design doc §7.4).

Standalone — no Godot dependency — so it runs in CI. It reads the same data the
game reads (data/rooms.json, data/notes.json, data/melodies/*.json) and proves
three things, exiting non-zero on any error:

  1. Reachability — every room and every gated door is reachable/openable from
     the start.
  2. The length ramp (§3.6) — a door's melody is no longer than the notes the
     player could hold before it opens. Enforced as a ceiling; a door easier than
     the ramp prescribes is a (non-fatal) warning, so a too-easy door is visible
     rather than silent (D-M3-8).
  3. Referential integrity — exits, gates, and note contents all resolve.

No pitch, melody, or musical pattern is hardcoded here: melodies and notes are
read from data, exactly as the game loads them (§7). The one thing spelled out is
the name->pitch-class map, which is notation, not content.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

# Note-name -> semitone within the octave. Mirrors NoteNames.SEMITONE; this is
# how notation works, not a melody, so it is not "musical content" (§3, §7).
SEMITONE = {
    "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3,
    "E": 4, "FB": 4, "E#": 5, "F": 5, "F#": 6, "GB": 6,
    "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10,
    "B": 11, "CB": 11, "B#": 0,
}

# design doc §3.6 ramp: notes held -> maximum melody length.
RAMP = {1: 1, 2: 2, 3: 3, 4: 3, 5: 4, 6: 5}


def ramp_ceiling(notes_held: int) -> int:
    if notes_held <= 0:
        return 0
    return RAMP.get(notes_held, 5)


def pitch_class(note_name: str):
    """Pitch class 0..11 for a name like 'C4'/'F#3'/'Bb2', or None if malformed."""
    text = note_name.strip()
    i = len(text)
    while i > 0 and (text[i - 1].isdigit() or text[i - 1] == "-"):
        i -= 1
    if i == 0 or i == len(text):
        return None
    letter = text[:i].upper()
    return SEMITONE.get(letter)


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def validate(rooms_graph: dict, notes: dict, melodies: dict) -> tuple[list[str], list[str]]:
    """Pure validator. Returns (errors, warnings) for the room graph.

    rooms_graph is the graph dict with 'start' and 'rooms' keys.
    notes maps id -> record.
    melodies maps id -> record.
    """
    errors: list[str] = []
    warnings: list[str] = []

    graph = rooms_graph
    rooms = graph.get("rooms", {})
    start = graph.get("start", {})

    def owned_pcs(note_ids) -> set:
        pcs = set()
        for nid in note_ids:
            rec = notes.get(nid)
            if rec:
                pc = SEMITONE.get(str(rec.get("pitch_class", "")).upper())
                if pc is not None:
                    pcs.add(pc)
        return pcs

    def melody_pcs(melody_id):
        """Pitch classes a door's melody demands, or None if the melody is bad."""
        m = melodies.get(melody_id)
        if m is None:
            return None
        pcs = set()
        for name in m.get("notes", []):
            pc = pitch_class(str(name))
            if pc is None:
                errors.append(f"melody '{melody_id}' has an unparseable note '{name}'")
                return None
            pcs.add(pc)
        return pcs

    # --- Referential integrity (§7.3) ---
    start_room = str(start.get("room", ""))
    if start_room not in rooms:
        errors.append(f"start room '{start_room}' is not defined")
    elif start.get("entry") not in rooms[start_room].get("entries", []):
        errors.append(f"start entry '{start.get('entry')}' is not in room '{start_room}'")

    for rid, room in rooms.items():
        for nid in room.get("notes", []):
            if nid not in notes:
                errors.append(f"room '{rid}' contains unknown note id '{nid}'")
        for ex in room.get("exits", []):
            to, to_entry = str(ex.get("to", "")), str(ex.get("to_entry", ""))
            if to not in rooms:
                errors.append(f"room '{rid}' exits to unknown room '{to}'")
            elif to_entry not in rooms[to].get("entries", []):
                errors.append(f"room '{rid}' exit to '{to}' names missing entry '{to_entry}'")
            door = str(ex.get("door", ""))
            req = ex.get("requires")
            if door and door not in melodies:
                errors.append(f"room '{rid}' exit gated by unknown melody '{door}'")
            if req is not None:
                need_id = str(req.get("note", ""))
                if need_id not in notes:
                    errors.append(f"room '{rid}' ability gate names unknown note '{need_id}'")

    # --- Reachability fixpoint (§7 algorithm) ---
    reachable = {start_room} if start_room in rooms else set()
    collected = set()
    for rid in reachable:
        collected |= set(rooms[rid].get("notes", []))
    door_opened_at: dict[str, int] = {}  # door -> notes held when first openable

    changed = True
    while changed:
        changed = False
        owned = owned_pcs(collected)
        for rid in list(reachable):
            for ex in rooms[rid].get("exits", []):
                door = str(ex.get("door", ""))
                req = ex.get("requires")
                passable = True
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
                if not passable:
                    continue
                to = str(ex.get("to", ""))
                if to in rooms and to not in reachable:
                    reachable.add(to)
                    collected |= set(rooms[to].get("notes", []))
                    changed = True

    # Reachability assertions.
    for rid in rooms:
        if rid not in reachable:
            errors.append(f"room '{rid}' is unreachable from the start")
    for rid, room in rooms.items():
        for ex in room.get("exits", []):
            door = str(ex.get("door", ""))
            if door and door in melodies and door not in door_opened_at:
                errors.append(f"door '{door}' (room '{rid}') can never be opened — unsolvable")

    # Ramp assertions.
    for door, held in sorted(door_opened_at.items()):
        length = len(melodies[door].get("notes", []))
        ceiling = ramp_ceiling(held)
        if length > ceiling:
            errors.append(
                f"door '{door}': melody length {length} exceeds the ramp ceiling "
                f"{ceiling} for {held} note(s) held"
            )
        elif length < ceiling:
            warnings.append(
                f"door '{door}': melody length {length} is below the ramp figure "
                f"{ceiling} for {held} note(s) held — guessable, consider lengthening (D-M3-8)"
            )

    return errors, warnings


def main() -> int:
    notes = {n["id"]: n for n in load_json(DATA / "notes.json").get("notes", [])}
    melodies = {}
    for path in sorted((DATA / "melodies").glob("*.json")):
        m = load_json(path)
        if "id" in m:
            melodies[m["id"]] = m

    graph = load_json(DATA / "rooms.json")

    errors, warnings = validate(graph, notes, melodies)

    for w in warnings:
        print(f"warning: {w}")
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"\nvalidate_rooms: FAILED with {len(errors)} error(s).", file=sys.stderr)
        return 1

    # For the summary, recompute door_opened_at (same algorithm as in validate)
    rooms = graph.get("rooms", {})
    start = graph.get("start", {})
    start_room = str(start.get("room", ""))
    reachable = {start_room} if start_room in rooms else set()
    collected = set()
    for rid in reachable:
        collected |= set(rooms[rid].get("notes", []))
    door_opened_at: dict[str, int] = {}

    changed = True
    while changed:
        changed = False
        owned = {SEMITONE.get(str(notes[nid].get("pitch_class", "")).upper())
                 for nid in collected if nid in notes}
        owned.discard(None)
        for rid in list(reachable):
            for ex in rooms[rid].get("exits", []):
                door = str(ex.get("door", ""))
                req = ex.get("requires")
                passable = False
                if req is not None:
                    need_id = str(req.get("note", ""))
                    passable = need_id in collected
                elif door:
                    m = melodies.get(door)
                    if m:
                        need = set()
                        for name in m.get("notes", []):
                            pc = pitch_class(str(name))
                            if pc is not None:
                                need.add(pc)
                        passable = need <= owned
                        if passable and door not in door_opened_at:
                            door_opened_at[door] = len(collected)
                else:
                    passable = True
                if not passable:
                    continue
                to = str(ex.get("to", ""))
                if to in rooms and to not in reachable:
                    reachable.add(to)
                    collected |= set(rooms[to].get("notes", []))
                    changed = True

    print(
        f"validate_rooms: OK — {len(rooms)} rooms reachable, "
        f"{len(door_opened_at)} door(s) solvable, ramp holds."
        + (f" ({len(warnings)} warning(s))" if warnings else "")
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
