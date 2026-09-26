#!/usr/bin/env python3
"""Shared room geometry for the Python tools (M6 Step 2b).

The Python side of `scripts/room/room_geometry.gd` (RoomGeometry) — the SAME placement maths
the game uses, in one place, so tools derive door footprints, openings and landings instead of
hand-keeping them. `seal_test.py` and `lint_rooms.py` both import this; keep the constants in
step with room_geometry.gd / door.gd / player.tscn (they mirror runtime values the validators
cannot read out of the engine).

Stdlib only.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

# --- Constants (mirror the runtime; see room_geometry.gd, door.gd, player.tscn) ---
TILE = 30                     # room_geometry tile size (§5.2)
DOOR_INSET = 1.5              # RoomGeometry.DOOR_INSET — leaf centre from the link cell
ENTRY_INSET = 1              # RoomGeometry.ENTRY_INSET — a plain transition landing
DOOR_ENTRY_INSET = 3.5       # RoomGeometry.DOOR_ENTRY_INSET — a doored transition landing
EDGE_THICK = 24.0            # RoomGeometry.EDGE_TRIGGER_THICKNESS
SLAB_W, SLAB_H = 72.0, 90.0  # door.gd slab_size (across × depth for a vertical door)
PLAYER = 30.0                # player.tscn CollisionShape2D (30×30)

ROOT = Path(__file__).resolve().parent.parent
ROOMS_DIR = ROOT / "data" / "rooms"


def cell_center(x: int, y: int) -> tuple[float, float]:
	return (x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)


def inward(at: tuple[int, int], w: int, h: int) -> tuple[int, int]:
	"""Unit step from a perimeter cell into the room; (0,0) for a non-perimeter cell."""
	x, y = at
	if x <= 0:
		return (1, 0)
	if x >= w - 1:
		return (-1, 0)
	if y <= 0:
		return (0, 1)
	if y >= h - 1:
		return (0, -1)
	return (0, 0)


def along(inw: tuple[int, int]) -> tuple[int, int]:
	"""The along-the-opening axis: perpendicular to `inward`."""
	return (abs(inw[1]), abs(inw[0]))


def opening_offset(inw: tuple[int, int]) -> tuple[float, float]:
	ax, ay = along(inw)
	return (ax * TILE * 0.5, ay * TILE * 0.5)


def inset_point(at: tuple[int, int], inw: tuple[int, int], inset_tiles: float) -> tuple[float, float]:
	cx, cy = cell_center(*at)
	ox, oy = opening_offset(inw)
	return (cx + inw[0] * inset_tiles * TILE + ox, cy + inw[1] * inset_tiles * TILE + oy)


def door_rect(at: tuple[int, int], inw: tuple[int, int]) -> tuple[float, float, float, float]:
	"""The door leaf's slab. Always 72px across × 90px deep in WORLD axes for both edges: for a
	vertical (N/S) door that is across=72 / depth=90, for a horizontal (E/W) door DoorLayout
	swaps across↔depth so the world extents come out the same 72×90 (matches seal_test.py and
	test_door_layout)."""
	dx, dy = inset_point(at, inw, DOOR_INSET)
	return (dx - SLAB_W * 0.5, dy - SLAB_H * 0.5, dx + SLAB_W * 0.5, dy + SLAB_H * 0.5)


def band_rect(at: tuple[int, int], inw: tuple[int, int]) -> tuple[float, float, float, float]:
	"""The edge-band exit trigger straddling the room boundary (RoomGeometry.edge_band_*)."""
	cx, cy = cell_center(*at)
	ox, oy = opening_offset(inw)
	bx = cx + ox - inw[0] * TILE * 0.5
	by = cy + oy - inw[1] * TILE * 0.5
	if inw[0] != 0:
		w, h = EDGE_THICK, TILE * 2.0
	else:
		w, h = TILE * 2.0, EDGE_THICK
	return (bx - w * 0.5, by - h * 0.5, bx + w * 0.5, by + h * 0.5)


def opening_cells(at: tuple[int, int], inw: tuple[int, int]) -> list[tuple[int, int]]:
	"""The two floor cells of a 2-tile opening: `at` and its neighbour along the edge."""
	ax, ay = along(inw)
	return [(at[0], at[1]), (at[0] + ax, at[1] + ay)]


def rect_to_cells(rect: tuple[float, float, float, float]) -> set[tuple[int, int]]:
	"""Every tile a pixel-space rect overlaps."""
	x0, y0, x1, y1 = rect
	cells: set[tuple[int, int]] = set()
	for cx in range(math.floor(x0 / TILE), math.ceil(x1 / TILE)):
		for cy in range(math.floor(y0 / TILE), math.ceil(y1 / TILE)):
			cells.add((cx, cy))
	return cells


def load_room(path: Path) -> dict:
	return json.loads(Path(path).read_text(encoding="utf-8"))


# --- Natural-walls rules (M7 natural-walls step) ---
# Rules 1–3 of the natural-walls spec, as lint warnings on rooms whose `geometry` is "natural".
# Thresholds are the owner's "stricter" ruling, to be retuned on the Hollow pilot.
GEOMETRY_KINDS = ("natural", "carved")
APRON_MIN = 4             # a straight flat run this deep at every exit (spec §6, §7)
MAX_STRAIGHT_RUN = 3      # rule 1: a wall face longer than this is a straight wall
MAX_UNIT_STEPS = 4        # rule 2: this many 1×1 alternating steps is a regular staircase
PIPE_MAX_WIDTH = 6        # rule 3: a channel this wide or narrower can be a pipe…
MAX_PIPE_LENGTH = 4       # …if it holds exactly one width for this many overlapping slices

Cell = tuple[int, int]
Finding = tuple[str, list[Cell]]

_DIRS = {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}


def _floor(grid: list[str], x: int, y: int) -> bool:
	"""Out of bounds counts as rock: the room is walled by its bounds."""
	return 0 <= y < len(grid) and 0 <= x < len(grid[y]) and grid[y][x] == "."


def door_reserved_cells(at: Cell, inw: Cell) -> set[Cell]:
	"""A door/gate leaf's footprint plus its 2-tile approach clearance inward."""
	cells = rect_to_cells(door_rect(at, inw))
	reserved = set(cells)
	for cell in cells:
		for k in (1, 2):
			reserved.add((cell[0] + inw[0] * k, cell[1] + inw[1] * k))
	return reserved


def exempt_cells(data: dict) -> set[Cell]:
	"""Cells rules 1–3 skip because other conventions require them straight: exit aprons and
	corridor slots, door/gate footprints with their approach, internal ability-gate zones — or
	every cell, for a carved room."""
	grid = data.get("grid", [])
	h = len(grid)
	w = len(grid[0]) if h else 0
	if data.get("geometry") == "carved":
		return {(x, y) for y in range(h) for x in range(w)}
	out: set[Cell] = set()
	for d in list(data.get("links", [])) + list(data.get("sealed_doors", [])):
		at = tuple(d.get("at", [0, 0]))
		inw = inward(at, w, h)
		if inw == (0, 0):
			continue
		# The corridor slot runs from the edge through the rock border to the apron's end.
		for c in opening_cells(at, inw):
			for k in range(0, APRON_MIN + 2):
				out.add((c[0] + inw[0] * k, c[1] + inw[1] * k))
		if d.get("door") or d.get("requires") or "sockets" in d:
			out |= door_reserved_cells(at, inw)
	for g in data.get("ability_gates", []):
		at = tuple(g.get("at", [0, 0]))
		cx, cy = cell_center(*at)
		slab = rect_to_cells((cx - SLAB_W * 0.5, cy - SLAB_H * 0.5, cx + SLAB_W * 0.5, cy + SLAB_H * 0.5))
		fx, fy = g.get("facing", [0, 1])
		out |= slab
		for c in slab:
			for k in (1, 2):
				out.add((c[0] + fx * k, c[1] + fy * k))
				out.add((c[0] - fx * k, c[1] - fy * k))
	return out


def straight_runs(grid: list[str], exempt: set[Cell]) -> list[Finding]:
	"""Rule 1: consecutive floor cells sharing one wall face (N/S along a row, E/W down a
	column) longer than MAX_STRAIGHT_RUN. Exempt cells break a run."""
	h = len(grid)
	w = len(grid[0]) if h else 0
	out: list[Finding] = []
	for face, (dx, dy) in _DIRS.items():
		horizontal = face in "NS"
		outer = range(h) if horizontal else range(w)
		inner = range(w) if horizontal else range(h)
		for a in outer:
			run: list[Cell] = []
			for b in list(inner) + [None]:
				cell = None if b is None else ((b, a) if horizontal else (a, b))
				walled = (
					cell is not None and cell not in exempt and _floor(grid, *cell)
					and not _floor(grid, cell[0] + dx, cell[1] + dy)
				)
				if walled:
					run.append(cell)
					continue
				if len(run) > MAX_STRAIGHT_RUN:
					out.append(("straight_run", run))
				run = []
	return out


def _boundary_loops(grid: list[str]) -> list[list[tuple[Cell, Cell, Cell]]]:
	"""The rock/floor boundary as closed loops of unit edges (start vertex, direction, owning
	floor cell), walked with floor on the left."""
	h = len(grid)
	w = len(grid[0]) if h else 0
	edges: dict[Cell, list[tuple[Cell, Cell]]] = {}
	for y in range(h):
		for x in range(w):
			if not _floor(grid, x, y):
				continue
			# Vertices are cell corners; each rock-facing side becomes one directed edge.
			if not _floor(grid, x, y - 1):
				edges.setdefault((x + 1, y), []).append(((-1, 0), (x, y)))
			if not _floor(grid, x - 1, y):
				edges.setdefault((x, y), []).append(((0, 1), (x, y)))
			if not _floor(grid, x, y + 1):
				edges.setdefault((x, y + 1), []).append(((1, 0), (x, y)))
			if not _floor(grid, x + 1, y):
				edges.setdefault((x + 1, y + 1), []).append(((0, -1), (x, y)))
	loops = []
	while edges:
		start = next(iter(edges))
		v = start
		loop = []
		prev_dir: Cell | None = None
		while v in edges and edges[v]:
			options = edges[v]
			pick = 0
			if prev_dir is not None and len(options) > 1:
				# A pinch vertex: turn left (keeps floor on the left, loops stay simple).
				left = (prev_dir[1], -prev_dir[0])
				pick = next((i for i, o in enumerate(options) if o[0] == left), 0)
			d, owner = options.pop(pick)
			if not options:
				del edges[v]
			loop.append((v, d, owner))
			prev_dir = d
			v = (v[0] + d[0], v[1] + d[1])
		loops.append(loop)
	return loops


def staircases(grid: list[str], exempt: set[Cell]) -> list[Finding]:
	"""Rule 2: MAX_UNIT_STEPS or more consecutive unit steps along the boundary — 1-tile
	segments, alternately horizontal and vertical, turning alternately left and right. That
	renders under the 45° bevel as a ruler-straight diagonal. Exempt cells break a sequence."""
	out: list[Finding] = []
	for loop in _boundary_loops(grid):
		# Compress unit edges into straight segments: (direction, length, owning cells).
		segs: list[tuple[Cell, int, list[Cell]]] = []
		for _, d, owner in loop:
			if segs and segs[-1][0] == d:
				segs[-1] = (d, segs[-1][1] + 1, segs[-1][2] + [owner])
			else:
				segs.append((d, 1, [owner]))
		if len(segs) > 1 and segs[0][0] == segs[-1][0]:
			d, n, cells = segs.pop()
			segs[0] = (d, n + segs[0][1], cells + segs[0][2])
		n = len(segs)
		if n < 2:
			continue

		def turn(i: int) -> int:
			a, b = segs[i % n][0], segs[(i + 1) % n][0]
			return a[0] * b[1] - a[1] * b[0]

		def unit(i: int) -> bool:
			s = segs[i % n]
			return s[1] == 1 and not any(c in exempt for c in s[2])

		# Walk from a non-unit segment so a staircase is never split across the loop's seam.
		begin = next((i for i in range(n) if not unit(i)), None)
		if begin is None:
			continue  # a loop made only of unit segments is a lone cell/pillar, not a wall
		run: list[int] = []
		for k in range(1, n + 1):
			i = begin + k
			# Extend while segments stay unit length and the turns keep alternating L/R/L/R.
			if unit(i) and (len(run) < 2 or (turn(run[-1]) != 0 and turn(run[-1]) == -turn(run[-2]))):
				run.append(i)
				continue
			if len(run) >= 2 * MAX_UNIT_STEPS:
				out.append(("staircase", [c for j in run for c in segs[j % n][2]]))
			run = [i] if unit(i) else []
	return out


def pipes(grid: list[str], exempt: set[Cell]) -> list[Finding]:
	"""Rule 3: a floor span ≤ PIPE_MAX_WIDTH, rock at both ends, holding exactly one width for
	MAX_PIPE_LENGTH consecutive overlapping slices — parallel walls, straight or diagonal.
	Checked on rows and on columns. A span touching an exempt cell breaks a chain."""
	h = len(grid)
	w = len(grid[0]) if h else 0
	out: list[Finding] = []
	for horizontal in (True, False):
		n_slices, n_len = (h, w) if horizontal else (w, h)
		done: list[list[tuple[int, int, int]]] = []
		active: list[list[tuple[int, int, int]]] = []  # each chain: [(slice, start, end), ...]
		for sl in range(n_slices):
			def at(v: int) -> Cell:
				return (v, sl) if horizontal else (sl, v)
			spans = []
			t = 0
			while t < n_len:
				if not _floor(grid, *at(t)):
					t += 1
					continue
				u = t
				while u + 1 < n_len and _floor(grid, *at(u + 1)):
					u += 1
				closed = t > 0 and u < n_len - 1  # rock at both ends, not the bounds' edge
				if closed and u - t + 1 <= PIPE_MAX_WIDTH and not any(at(v) in exempt for v in range(t, u + 1)):
					spans.append((sl, t, u))
				t = u + 1
			nxt: list[list[tuple[int, int, int]]] = []
			used: set[int] = set()
			for sp in spans:
				chain = [sp]
				for ci, ch in enumerate(active):
					_, a0, b0 = ch[-1]
					if ci not in used and b0 - a0 == sp[2] - sp[1] and a0 <= sp[2] and sp[1] <= b0:
						used.add(ci)
						chain = ch + [sp]
						break
				nxt.append(chain)
			done += [ch for ci, ch in enumerate(active) if ci not in used]
			active = nxt
		for ch in done + active:
			if len(ch) >= MAX_PIPE_LENGTH:
				cells = [((a, sl) if horizontal else (sl, a)) for sl, a, _ in ch]
				out.append(("pipe", cells))
	return out


def teeth(grid: list[str], exempt: set[Cell]) -> list[Finding]:
	"""Rule 3a (spec amendment, Hollow pilot round 2): a cell 1 tile thick with the other
	material on both opposite sides — a rock fin or a floor slot. Under the 45° bevel it draws as
	a V-spike, which reads as noise; rules 1–3 miss it because a 1-row zigzag is neither a
	straight run nor a monotonic staircase. Out of bounds counts as rock, as everywhere here."""
	out: list[Finding] = []
	for y, row in enumerate(grid):
		for x in range(len(row)):
			if (x, y) in exempt:
				continue
			me = _floor(grid, x, y)
			if (_floor(grid, x - 1, y) != me and _floor(grid, x + 1, y) != me) or (
				_floor(grid, x, y - 1) != me and _floor(grid, x, y + 1) != me
			):
				out.append(("tooth", [(x, y)]))
	return out


def wall_findings(data: dict) -> list[Finding]:
	"""All rule 1–3a findings for one room; empty for a carved room."""
	if data.get("geometry") != "natural":
		return []
	grid = data.get("grid", [])
	ex = exempt_cells(data)
	return straight_runs(grid, ex) + staircases(grid, ex) + pipes(grid, ex) + teeth(grid, ex)
