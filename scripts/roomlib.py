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
