#!/usr/bin/env python3
"""Room geometry lint (M6 Step 2b).

The checks a room used to pass by eye, as machine checks — run beside validate_rooms.py and
seal_test.py after any room change, and green before a new room's shape is frozen. It reads the
per-room GEOMETRY files (data/rooms/<id>.json: grid, links, entries, content) — a different
schema from the graph (data/rooms.json) that validate_rooms.py reasons about.

Door footprints, openings and landings are DERIVED from link positions with the shared
`roomlib` maths (the Python mirror of RoomGeometry) — never a hand-kept list, which is the whole
point (spec §5 friction).

ERRORS (exit non-zero) are structural: the room would not work. WARNINGS (exit zero) are
convention and quality — legacy grey-box rooms trip these on purpose until M7 rebuilds them.

    python3 scripts/lint_rooms.py                 # every room in data/rooms/
    python3 scripts/lint_rooms.py room_a room_b   # named rooms

Stdlib only.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import roomlib
from roomlib import APRON_MIN, ROOMS_DIR

BASELINE = roomlib.ROOT / "data" / "lint_baseline.json"
WALL_RULES = ("straight_run", "staircase", "pipe", "tooth")
ROCK_TARGET = (0.20, 0.30)  # fraction of the bounds left as rock, excluding outcrops (§5, §7)


def lint_room(data: dict, accepted: list | None = None) -> tuple[list[str], list[str]]:
	"""Return (errors, warnings) for one room geometry dict. Pure — no I/O — so a fixture can
	drive it. `accepted` is this room's baseline entries; wall findings in it are not warned."""
	errors: list[str] = []
	warnings: list[str] = []

	if data.get("geometry") not in roomlib.GEOMETRY_KINDS:
		errors.append(
			f"geometry is {data.get('geometry')!r}; must be one of {list(roomlib.GEOMETRY_KINDS)}"
		)

	grid = data.get("grid", [])
	rows = len(grid)
	cols = len(grid[0]) if rows else 0
	size = list(data.get("size_tiles", [0, 0]))

	# --- Grid integrity (errors) ---
	if size != [cols, rows]:
		errors.append(f"size_tiles {size} does not match the grid ({cols}×{rows})")
	ragged = [i for i, row in enumerate(grid) if len(row) != cols]
	if ragged:
		errors.append(f"rows {ragged} are not {cols} wide (grid is ragged)")
	bad = sorted({ch for row in grid for ch in row if ch not in "#.o"})
	if bad:
		errors.append(f"grid has characters outside '#.o': {bad}")

	# A ragged or empty grid makes cell lookups meaningless — stop before the geometry rules.
	if not rows or ragged:
		return errors, warnings

	def in_bounds(x: int, y: int) -> bool:
		return 0 <= x < cols and 0 <= y < rows

	def is_floor(x: int, y: int) -> bool:
		return in_bounds(x, y) and grid[y][x] == "."

	def perimeter_openings(defs: list, label: str) -> None:
		"""links and sealed_doors both sit at a 2-tile perimeter opening."""
		for d in defs:
			at = tuple(d.get("at", [0, 0]))
			inw = roomlib.inward(at, cols, rows)
			name = d.get("door") or d.get("melody_id") or label
			if inw == (0, 0):
				errors.append(f"{label} '{name}' at {at} is not on the perimeter")
				continue
			for c in roomlib.opening_cells(at, inw):
				if not is_floor(*c):
					errors.append(f"{label} '{name}' at {at}: opening cell {tuple(c)} is not floor")

	perimeter_openings(data.get("links", []), "link")
	perimeter_openings(data.get("sealed_doors", []), "sealed_door")

	# --- Content on floor, in bounds (errors) ---
	def check_on_floor(items: list, kind: str, key: str) -> None:
		for it in items:
			at = tuple(it.get("at", [0, 0]))
			ident = it.get(key, "")
			if not in_bounds(*at):
				errors.append(f"{kind} '{ident}' at {at} is out of bounds")
			elif not is_floor(*at):
				errors.append(f"{kind} '{ident}' at {at} is not on floor")

	check_on_floor(data.get("pickups", []), "pickup", "note_id")
	check_on_floor(data.get("chimes", []), "chime", "melody_id")
	check_on_floor(data.get("props", []), "prop", "at")

	# --- Entry landings (errors) ---
	links = data.get("links", [])
	for entry_id, cell in data.get("entries", {}).items():
		cell = tuple(cell)
		if str(entry_id).startswith("from_") and links:
			link = _nearest_link(links, cell)
			at = tuple(link.get("at", [0, 0]))
			inw = roomlib.inward(at, cols, rows)
			inset = roomlib.DOOR_ENTRY_INSET if (link.get("door") or link.get("requires")) else float(roomlib.ENTRY_INSET)
			lx, ly = roomlib.inset_point(at, inw, inset)
			landing = (int(lx // roomlib.TILE), int(ly // roomlib.TILE))
			if not is_floor(*landing):
				errors.append(f"entry '{entry_id}' lands on {landing}, which is not floor")
		elif not is_floor(*cell):
			errors.append(f"entry '{entry_id}' at {cell} is not on floor")

	# --- Door footprint / approach clearance holds no content (errors) ---
	content_cells = _content_cells(data)
	for d in list(data.get("links", [])) + list(data.get("sealed_doors", [])):
		at = tuple(d.get("at", [0, 0]))
		inw = roomlib.inward(at, cols, rows)
		has_leaf = d.get("door") is not None or "melody_id" in d or "sockets" in d or d.get("requires") is not None
		if inw == (0, 0) or not has_leaf:
			continue  # a plain (free) link reserves nothing
		name = d.get("door") or ("ability gate" if d.get("requires") else "sealed_door")
		reserved = _reserved_cells(at, inw)
		for cell, what in content_cells:
			if cell in reserved:
				errors.append(f"{what} at {cell} sits in door '{name}'s reserved footprint/approach")

	# --- Apron depth (warning) ---
	for d in list(data.get("links", [])) + list(data.get("sealed_doors", [])):
		at = tuple(d.get("at", [0, 0]))
		inw = roomlib.inward(at, cols, rows)
		if inw == (0, 0):
			continue
		for c in roomlib.opening_cells(at, inw):
			for k in range(1, APRON_MIN + 1):
				cell = (c[0] + inw[0] * k, c[1] + inw[1] * k)
				if not is_floor(*cell):
					warnings.append(
						f"exit at {at}: apron cell {cell} ({k} tile(s) in) is not floor — "
						f"want a straight {APRON_MIN}-tile apron"
					)
					break

	# --- Rock percentage (report; warn if the target is missed) ---
	total = rows * cols
	rock = sum(row.count("#") + row.count("o") for row in grid)
	outcrop = sum(row.count("o") for row in grid)
	excl = (rock - outcrop) / total if total else 0.0
	incl = rock / total if total else 0.0
	warnings.append(
		f"rock {excl * 100:.1f}% excl outcrops / {incl * 100:.1f}% incl "
		f"(target {int(ROCK_TARGET[0] * 100)}–{int(ROCK_TARGET[1] * 100)}% excl)"
	)
	if not ROCK_TARGET[0] <= excl <= ROCK_TARGET[1]:
		warnings.append(
			f"rock {excl * 100:.1f}% (excl outcrops) is outside the "
			f"{int(ROCK_TARGET[0] * 100)}–{int(ROCK_TARGET[1] * 100)}% target"
		)

	# --- Natural walls, rules 1–3 (warnings; the owner's baseline accepts some) ---
	for rule, cells in unaccepted_walls(data, accepted or []):
		warnings.append(f"{rule} at {cells[0]} ({len(cells)} cells)")

	return errors, warnings


def _baseline_key(rule: str, cell) -> tuple[str, tuple[int, int]]:
	return (rule, (int(cell[0]), int(cell[1])))


def split_walls(data: dict, accepted: list) -> tuple[list, list]:
	"""(unaccepted, accepted) wall findings. A baseline entry names a finding by its rule and
	first cell — the same thing the warning prints, so it can be copied straight in."""
	keys = {_baseline_key(a["rule"], a["at"]) for a in accepted}
	fresh, ok = [], []
	for rule, cells in roomlib.wall_findings(data):
		(ok if _baseline_key(rule, cells[0]) in keys else fresh).append((rule, cells))
	return fresh, ok


def unaccepted_walls(data: dict, accepted: list) -> list:
	return split_walls(data, accepted)[0]


def load_baseline() -> dict:
	return json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else {}


def _nearest_link(links: list, cell: tuple[int, int]) -> dict:
	best, best_d = {}, float("inf")
	for link in links:
		at = tuple(link.get("at", [0, 0]))
		d = (cell[0] - at[0]) ** 2 + (cell[1] - at[1]) ** 2
		if d < best_d:
			best_d, best = d, link
	return best


def _content_cells(data: dict) -> list[tuple[tuple[int, int], str]]:
	out: list[tuple[tuple[int, int], str]] = []
	for p in data.get("pickups", []):
		out.append((tuple(p.get("at", [0, 0])), f"pickup '{p.get('note_id', '')}'"))
	for c in data.get("chimes", []):
		out.append((tuple(c.get("at", [0, 0])), f"chime '{c.get('melody_id', '')}'"))
	for pr in data.get("props", []):
		out.append((tuple(pr.get("at", [0, 0])), "prop"))
	return out


_reserved_cells = roomlib.door_reserved_cells


def _targets(argv: list[str]) -> list[Path]:
	if not argv:
		return sorted(ROOMS_DIR.glob("*.json"))
	paths = []
	for a in argv:
		p = Path(a)
		if not p.exists():
			p = ROOMS_DIR / (a if a.endswith(".json") else f"{a}.json")
		paths.append(p)
	return paths


def main(argv: list[str]) -> int:
	targets = _targets(argv)
	if not targets:
		print("lint_rooms: no room files found", file=sys.stderr)
		return 1
	total_errors = 0
	baseline = load_baseline()
	for path in targets:
		data = roomlib.load_room(path)
		accepted = baseline.get(data.get("room_id", path.stem), [])
		errors, warnings = lint_room(data, accepted)
		total_errors += len(errors)
		status = "FAIL" if errors else "ok  "
		print(f"{status}  {path.name}")
		for w in warnings:
			print(f"      warning: {w}")
		fresh, ok = split_walls(data, accepted)
		for rule, cells in ok:
			print(f"      accepted: {rule} at {cells[0]} ({len(cells)} cells)")
		counts = "  ".join(
			f"{r} {sum(1 for f in fresh if f[0] == r)}+{sum(1 for f in ok if f[0] == r)}acc"
			for r in WALL_RULES
		)
		rock = sum(row.count("#") for row in data.get("grid", []))
		cells_total = sum(len(row) for row in data.get("grid", [])) or 1
		print(f"      summary: [{data.get('geometry', '?')}]  {counts}  rock {rock / cells_total * 100:.1f}%")
		for e in errors:
			print(f"      error:   {e}", file=sys.stderr)
	if total_errors:
		print(f"\nlint_rooms: FAILED with {total_errors} error(s).", file=sys.stderr)
		return 1
	print(f"\nlint_rooms: OK — {len(targets)} room(s), no errors.")
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
