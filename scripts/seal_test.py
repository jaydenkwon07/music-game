#!/usr/bin/env python3
"""Door seal test (M5 Step 5a).

Proves, for every melody-locked door in room_a, that CLOSED it makes its edge-trigger
band UNREACHABLE (no bypass past the leaf) and OPEN it makes the band REACHABLE
(solvable). This is a gate guarantee `validate_rooms.py` cannot give: that validator
reasons about tiles, but a door is a 72x90 slab centred at a fractional tile and the
player is a 30x30 box, so whether the slab actually seals the two-tile opening is a
question in continuous space, not on the grid.

Model. The player is a 30x30 box; a centre is FREE when the box overlaps no rock cell
(30x30), no CLOSED door slab, and stays inside the room. Reachability is an 8-connected
flood-fill of the centre on a fine grid — the step is small against the box, so it
cannot slip through a corner a continuous box could not. The door slab is 72 wide over a
60-wide (two-tile) opening, so it overlaps the neck walls on both sides; that overlap is
why Step 2c's rock bevel opens no bypass AT the door (a bevel only shaves an exposed rock
corner, and here the slab already covers those corners). The diagonal squeeze a bevel can
open between two free-standing rock cells is a separate, whole-map concern — see
m5-progress "Carry to 5a" — and is out of scope for this four-room seal.

Numbers mirror the code: TILE from room.gd, DOOR_INSET/opening from room.gd, SLAB from
door.gd (slab_size), PLAYER from player.tscn. Keep them in sync if those change.

Exit non-zero on any failure, like validate_rooms.py.
"""

import json
import sys
from collections import deque
from pathlib import Path

TILE = 30
DOOR_INSET = 1.5            # room.gd DOOR_INSET
SLAB_W, SLAB_H = 72.0, 90.0  # door.gd slab_size
PLAYER = 30.0              # player.tscn CollisionShape2D (30x30)
EDGE_THICK = 24.0          # room.gd EDGE_TRIGGER_THICKNESS
STEP = 5.0                 # flood-fill sampling, small vs PLAYER

ROOM = Path(__file__).resolve().parent.parent / "data" / "rooms" / "room_a.json"


def cell_center(x, y):
    return (x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)


def inward(at, w, h):
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


def opening_offset(inw):
    ix, iy = inw
    return (abs(iy) * TILE * 0.5, abs(ix) * TILE * 0.5)


def door_rect(link_at, inw):
    cx, cy = cell_center(*link_at)
    ox, oy = opening_offset(inw)
    dx = cx + inw[0] * DOOR_INSET * TILE + ox
    dy = cy + inw[1] * DOOR_INSET * TILE + oy
    return (dx - SLAB_W * 0.5, dy - SLAB_H * 0.5, dx + SLAB_W * 0.5, dy + SLAB_H * 0.5)


def band_rect(link_at, inw):
    # room.gd _edge_band_position / _edge_band_size: the trigger straddling the boundary.
    cx, cy = cell_center(*link_at)
    ox, oy = opening_offset(inw)
    bx = cx + ox - inw[0] * TILE * 0.5
    by = cy + oy - inw[1] * TILE * 0.5
    if inw[0] != 0:
        w, h = EDGE_THICK, TILE * 2.0
    else:
        w, h = TILE * 2.0, EDGE_THICK
    return (bx - w * 0.5, by - h * 0.5, bx + w * 0.5, by + h * 0.5)


def overlaps(box, rect):
    bx0, by0, bx1, by1 = box
    rx0, ry0, rx1, ry1 = rect
    return bx0 < rx1 and bx1 > rx0 and by0 < ry1 and by1 > ry0


def build_rock_rects(grid):
    rects = []
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in "#o":
                rects.append((x * TILE, y * TILE, (x + 1) * TILE, (y + 1) * TILE))
    return rects


def reachable_bands(grid, rock, w_px, h_px, closed_slabs, targets, start):
    """Flood-fill the player centre from `start`; return the set of target indices whose
    band the player box can overlap."""
    half = PLAYER * 0.5
    blockers = rock + closed_slabs

    def free(cx, cy):
        box = (cx - half, cy - half, cx + half, cy + half)
        if box[0] < 0 or box[1] < 0 or box[2] > w_px or box[3] > h_px:
            return False
        return not any(overlaps(box, r) for r in blockers)

    def snap(v):
        return round(v / STEP) * STEP

    sx, sy = snap(start[0]), snap(start[1])
    if not free(sx, sy):
        raise SystemExit(f"seal_test: start {start} is not free — check spawn/geometry")

    seen = {(sx, sy)}
    q = deque([(sx, sy)])
    hit = set()
    while q:
        cx, cy = q.popleft()
        box = (cx - half, cy - half, cx + half, cy + half)
        for i, t in enumerate(targets):
            if i not in hit and overlaps(box, t):
                hit.add(i)
        for dx in (-STEP, 0, STEP):
            for dy in (-STEP, 0, STEP):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = round(cx + dx, 3), round(cy + dy, 3)
                if (nx, ny) not in seen and free(nx, ny):
                    seen.add((nx, ny))
                    q.append((nx, ny))
    return hit


def main():
    data = json.loads(ROOM.read_text())
    grid = data["grid"]
    h, w = len(grid), len(grid[0])
    w_px, h_px = w * TILE, h * TILE
    rock = build_rock_rects(grid)
    start = cell_center(*data["entries"]["spawn"])

    doors = []  # (name, slab_rect, band_rect)
    for link in data["links"]:
        if not link.get("door"):
            continue
        at = tuple(link["at"])
        inw = inward(at, w, h)
        doors.append((link["door"], door_rect(at, inw), band_rect(at, inw)))

    if not doors:
        raise SystemExit("seal_test: no doored links in room_a")

    slabs = [d[1] for d in doors]
    bands = [d[2] for d in doors]
    ok = True

    # Each door CLOSED (others open) must make its own band unreachable.
    for i, (name, _slab, _band) in enumerate(doors):
        hit = reachable_bands(grid, rock, w_px, h_px, [slabs[i]], bands, start)
        if i in hit:
            print(f"  FAIL  {name} closed: its edge trigger is still REACHABLE (bypass)")
            ok = False
        else:
            print(f"  ok    {name} closed: edge trigger sealed")

    # All doors OPEN: every band must be reachable (solvable).
    hit = reachable_bands(grid, rock, w_px, h_px, [], bands, start)
    for i, (name, _slab, _band) in enumerate(doors):
        if i in hit:
            print(f"  ok    {name} open: edge trigger reachable")
        else:
            print(f"  FAIL  {name} open: edge trigger UNREACHABLE even open")
            ok = False

    print("seal_test: OK" if ok else "seal_test: FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
