#!/usr/bin/env python3
"""Fixture tests for lint_rooms (M6 Step 2b) — one per rule, proving it fires.

Uses the real room_a as a known-good baseline, then mutates a copy to trip each rule and
asserts the matching message appears. Run:

    python3 scripts/test_lint_rooms.py

Exit non-zero on any failure, like the other Python tools. Stdlib only, no pytest (repo style).
"""

from __future__ import annotations

import copy
import sys

import roomlib
from lint_rooms import lint_room

BASE = roomlib.load_room(roomlib.ROOMS_DIR / "room_a.json")

_passed = 0
_failed = 0


def check(cond: bool, label: str) -> None:
	global _passed, _failed
	if cond:
		_passed += 1
		print(f"  ok    {label}")
	else:
		_failed += 1
		print(f"  FAIL  {label}")


def clone() -> dict:
	return copy.deepcopy(BASE)


def set_cell(room: dict, x: int, y: int, ch: str) -> None:
	row = list(room["grid"][y])
	row[x] = ch
	room["grid"][y] = "".join(row)


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
		"pickups": [], "chimes": [], "sealed_doors": [], "props": [{"at": list(prop_at)}],
	}


def has(msgs: list[str], needle: str) -> bool:
	return any(needle in m for m in msgs)


def main() -> int:
	# Baseline: the reference room is error-clean.
	errors, warnings = lint_room(BASE)
	check(errors == [], "room_a has no errors")
	check(has(warnings, "rock 29.9% excl"), "room_a reports its rock percentage")

	# size_tiles mismatch.
	r = clone(); r["size_tiles"] = [47, 36]
	check(has(lint_room(r)[0], "does not match the grid"), "size_tiles mismatch is an error")

	# Bad grid character.
	r = clone(); set_cell(r, 5, 5, "X")
	check(has(lint_room(r)[0], "outside '#.o'"), "a stray grid character is an error")

	# Ragged row.
	r = clone(); r["grid"][3] = r["grid"][3] + "."
	check(has(lint_room(r)[0], "ragged"), "a ragged row is an error")

	# Link off the perimeter.
	r = clone(); r["links"][0]["at"] = [10, 10]
	check(has(lint_room(r)[0], "not on the perimeter"), "an interior link is an error")

	# Opening cell not floor.
	r = clone(); set_cell(r, 23, 0, "#")  # block one cell of door_backtrack's N opening
	check(has(lint_room(r)[0], "opening cell"), "a rocked-over opening is an error")

	# Pickup off floor.
	r = clone(); r["pickups"][0]["at"] = [0, 0]  # the NW rock corner
	check(has(lint_room(r)[0], "is not on floor"), "content off floor is an error")

	# Content in a door's reserved footprint.
	r = clone(); r.setdefault("props", []).append({"at": [23, 2]})  # inside door_backtrack's leaf
	check(has(lint_room(r)[0], "reserved footprint"), "content in a door footprint is an error")

	# Entry landing not floor.
	r = clone(); r["entries"]["spawn"] = [0, 0]
	check(has(lint_room(r)[0], "not on floor"), "a spawn on rock is an error")

	# Apron too shallow (warning).
	r = clone(); set_cell(r, 45, 13, "#")  # block door_tutorial's E apron 2 tiles in
	check(has(lint_room(r)[1], "apron cell"), "a blocked apron is a warning")

	# Rock percentage outside target (warning).
	r = clone()
	for y in range(4, 32):  # carve out most of the rock so excl drops well below 20%
		r["grid"][y] = "." * len(r["grid"][y])
	check(has(lint_room(r)[1], "outside the 20–30% target"), "off-target rock is a warning")

	# Ability gate footprint: prop in the gate leaf.
	errors, _ = lint_room(_gate_room((9, 2)))
	check(has(errors, "reserved footprint"), "a prop in an ability gate footprint is an error")

	# Ability gate footprint: prop clear of the gate.
	errors, _ = lint_room(_gate_room((5, 2)))
	check(not has(errors, "reserved footprint"), "a prop clear of an ability gate is ok")

	print(f"\n{_passed} passed, {_failed} failed")
	return 1 if _failed else 0


if __name__ == "__main__":
	sys.exit(main())
