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

Numbers and placement maths now come from `roomlib` (the Python mirror of RoomGeometry), so
this no longer hand-keeps them — the M6 Step 2b consolidation. STEP is the one seal-test-only
knob. door_rect/band_rect are derived there, not here.

Exit non-zero on any failure, like validate_rooms.py.
"""

import sys
from collections import deque

import roomlib
from roomlib import PLAYER, TILE, cell_center, door_rect, band_rect, inward

STEP = 5.0                 # flood-fill sampling, small vs PLAYER

ROOM = roomlib.ROOMS_DIR / "room_a.json"


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
    data = roomlib.load_room(ROOM)
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
