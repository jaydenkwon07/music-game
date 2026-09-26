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
		"room_id": "gate_fixture", "geometry": "natural", "size_tiles": [12, 6], "grid": grid,
		"entries": {"from_east": [11, 2]},
		"links": [{"at": [11, 2], "to_room": "x", "to_entry": "from_gate",
		           "requires": {"note": "n_step"}}],
		"pickups": [], "chimes": [], "sealed_doors": [], "props": [{"at": list(prop_at)}],
	}


def _gate_inset_room():
	# 12-wide x 6-tall, an east opening at rows 2-3 with a requires link and entry.
	# Floor is carved so that DOOR_ENTRY_INSET (3.5) landing at col 8 is on floor,
	# but ENTRY_INSET (1) landing at col 10 is on rock. This tests that requires
	# links use DOOR_ENTRY_INSET, not ENTRY_INSET.
	grid = ["############"] * 6
	grid[2] = "###########."
	grid[3] = "###########."
	grid = [list(r) for r in grid]
	# Carve cols 4-8 as floor at rows 2-3 (covers the 3.5-tile deep landing at col 8)
	for y in (2, 3):
		for x in range(4, 9):  # 4,5,6,7,8 only
			grid[y][x] = "."
	grid = ["".join(r) for r in grid]
	return {
		"room_id": "inset_fixture", "geometry": "natural", "size_tiles": [12, 6], "grid": grid,
		"entries": {"from_east": [11, 2]},
		"links": [{"at": [11, 2], "to_room": "x", "to_entry": "from_gate",
		           "requires": {"note": "n_step"}}],
		"pickups": [], "chimes": [], "sealed_doors": [], "props": [],
	}


def _walled(grid: list[str], geometry: str = "natural", links: list | None = None) -> dict:
	"""A bare room around a hand-written grid, for the natural-walls rules."""
	return {
		"room_id": "walls_fixture", "geometry": geometry,
		"size_tiles": [len(grid[0]), len(grid)], "grid": grid,
		"entries": {}, "links": links or [], "pickups": [], "chimes": [], "props": [],
	}


def walls() -> None:
	"""Natural-walls rules 1–3 (M7 natural-walls step): one grid that must warn and one that
	must not per rule, plus the exemptions and the baseline."""
	# Rule 1: a 3-tile flat ceiling exceeds MAX_STRAIGHT_RUN = 2; a ceiling broken every 2 does not.
	flat = ["#######", "#.....#", "##...##", "#######"]
	check(has(lint_room(_walled(flat))[1], "straight_run"), "a 5-tile flat wall warns straight_run")
	broken = ["########", "###..###", "#..##..#", "#......#", "##.##.##", "########"]
	check(not has(lint_room(_walled(broken))[1], "straight_run"), "walls broken every 2 tiles pass")

	# Rule 2: four regular 1×1 steps warn; the same diagonal stepped 1,2,1,3 does not.
	stairs = ["#######", "#.#####", "#..####", "#...###", "#....##", "#.....#", "#######"]
	check(has(lint_room(_walled(stairs))[1], "staircase"), "a regular 1,1,1,1 staircase warns")
	uneven = ["#########", "#.#######", "#..######", "#....####", "#.....###", "#........", "#########"]
	uneven[5] = "#.......#"
	check(not has(lint_room(_walled(uneven))[1], "staircase"), "an uneven 1,2,1,3 diagonal passes")

	# Rule 3: a 2-wide channel holding its width for 5 rows warns; one that wanders does not.
	pipe = ["######", "##..##", "##..##", "##..##", "##..##", "##..##", "######"]
	check(has(lint_room(_walled(pipe))[1], "pipe"), "a parallel-walled channel warns pipe")
	wander = ["#######", "##..###", "#...###", "##...##", "##..###", "###...#", "#######"]
	check(not has(lint_room(_walled(wander))[1], "pipe"), "a channel whose width wanders passes")

	# Exempt: a straight exit apron. The corridor slot to the east edge is required-straight.
	apron = ["#########", "###......", "#........", "#..#.#.##", "#########"]
	room = _walled(apron, links=[{"at": [8, 1], "to_room": "x", "to_entry": "y"}])
	check(has(lint_room(_walled(apron))[1], "straight_run")
		and not has(lint_room(room)[1], "straight_run"), "an exit apron's straight walls are exempt")

	# Exempt: every cell of a carved room.
	carved = lint_room(_walled(flat, "carved"))[1]
	check(not any(has(carved, r) for r in ("straight_run", "staircase", "pipe")), "a carved room is exempt")

	# Baseline: an accepted finding is suppressed; copy the rule + first cell from the warning.
	accepted = [{"rule": "straight_run", "at": [1, 1]}, {"rule": "straight_run", "at": [1, 1]}]
	fresh = [w for w in lint_room(_walled(flat), accepted)[1] if "straight_run at (1, 1)" in w]
	check(fresh == [], "a baseline entry suppresses its warning")

	# Rule 3a (tooth): a cell 1 tile thick with the other material on both opposite sides.
	box = ["##########", "##########", "#........#", "#........#", "#........#",
	       "#........#", "#........#", "#........#", "##########"]
	fin = list(box); fin[4] = "#...#....#"          # a lone rock cell in open floor
	check(has(lint_room(_walled(fin))[1], "tooth at (4, 4)"), "a 1-tile rock fin warns tooth")
	mass = list(box); mass[4] = mass[5] = "#...##...#"  # the same rock as a 2×2 mass, 2 clear all round
	check(not has(lint_room(_walled(mass))[1], "tooth"), "a 2×2 rock mass passes")
	slot = list(box); slot[1] = "####.#####"          # a 1-wide notch up into the ceiling
	check(has(lint_room(_walled(slot))[1], "tooth at (4, 1)"), "a 1-tile floor slot warns tooth")
	alcove = list(box); alcove[1] = "###..#####"      # the same notch 2 wide
	check(not has(lint_room(_walled(alcove))[1], "tooth"), "a 2-wide alcove passes")
	lane = ["#########", "#########", "#...#....", "#........", "#########"]  # rock fin in the apron lane
	exit_link = [{"at": [8, 2], "to_room": "x", "to_entry": "y"}]
	check(has(lint_room(_walled(lane))[1], "tooth at (4, 2)")
		and not has(lint_room(_walled(lane, links=exit_link))[1], "tooth"), "a tooth inside an exit apron is exempt")

	# The geometry field is required and closed.
	r = _walled(flat); del r["geometry"]
	check(has(lint_room(r)[0], "geometry is None"), "a missing geometry field is an error")
	check(has(lint_room(_walled(flat, "cave"))[0], "geometry is 'cave'"), "an unknown geometry is an error")


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
	r = clone(); set_cell(r, 23, 0, "#")  # block one cell of door_omega's N opening
	check(has(lint_room(r)[0], "opening cell"), "a rocked-over opening is an error")

	# Pickup off floor. room_a no longer carries a pickup of its own (n_break moved to
	# room_hollow at M7), so append a synthetic one rather than mutating index 0.
	r = clone(); r.setdefault("pickups", []).append({"note_id": "n_test", "at": [0, 0]})  # NW rock corner
	check(has(lint_room(r)[0], "is not on floor"), "content off floor is an error")

	# Content in a door's reserved footprint.
	r = clone(); r.setdefault("props", []).append({"at": [23, 2]})  # inside door_omega's leaf
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

	# Entry landing with DOOR_ENTRY_INSET for requires link: floor carved to 3.5 tiles deep,
	# so DOOR_ENTRY_INSET landing is on floor, but ENTRY_INSET landing would be on rock.
	# This tests that requires links use DOOR_ENTRY_INSET (not ENTRY_INSET).
	errors, _ = lint_room(_gate_inset_room())
	check(errors == [], "entry landing for requires link uses DOOR_ENTRY_INSET (lands on floor)")

	walls()

	print(f"\n{_passed} passed, {_failed} failed")
	return 1 if _failed else 0


if __name__ == "__main__":
	sys.exit(main())
