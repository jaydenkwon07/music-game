#!/usr/bin/env python3
"""One-time M4 Step 0 migration: upscale every room geometry file 2x (spec §4.2).

The internal resolution moves from 320x180 to 640x360, tiles stay 20px, so the
grid goes from 16x9 to 32x18. Each old cell becomes a 2x2 block: the grid is
doubled in both axes and every stored coordinate doubles.

The one subtlety is links. A link's `at` is a PERIMETER cell, and `Room._inward()`
detects the edge by comparing against `size - 1`. When a cell becomes a 2x2 block,
a right/bottom-edge opening's perimeter cell is the FAR corner of the block —
`2c + 1`, not `2c` — otherwise the doubled coordinate lands one cell inside the
new wall line and edge detection (and door placement) breaks. Min-side edges
(x==0 / y==0) map to `2c` unchanged. Interior coordinates (entries, pickups,
chimes) are plain `2c`.

Idempotent guard: a room already at 32-wide is left untouched, so a second run is
a no-op rather than a 4x blow-up.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOMS_DIR = ROOT / "data" / "rooms"


def double_grid(grid: list[str]) -> list[str]:
    """Each char -> 2 chars, each row -> 2 rows."""
    wide = ["".join(ch * 2 for ch in row) for row in grid]
    return [row for row in wide for _ in range(2)]


def double_point(p: list[int]) -> list[int]:
    return [p[0] * 2, p[1] * 2]


def double_link_at(at: list[int], old_w: int, old_h: int) -> list[int]:
    """Perimeter cell of the 2x2 block: far corner on max-side edges."""
    nx = at[0] * 2 + 1 if at[0] == old_w - 1 else at[0] * 2
    ny = at[1] * 2 + 1 if at[1] == old_h - 1 else at[1] * 2
    return [nx, ny]


def migrate(geo: dict) -> dict:
    old_w, old_h = geo["size_tiles"]
    geo["size_tiles"] = [old_w * 2, old_h * 2]
    geo["grid"] = double_grid(geo["grid"])
    geo["entries"] = {name: double_point(p) for name, p in geo.get("entries", {}).items()}
    for link in geo.get("links", []):
        link["at"] = double_link_at(link["at"], old_w, old_h)
    for pickup in geo.get("pickups", []):
        pickup["at"] = double_point(pickup["at"])
    for chime in geo.get("chimes", []):
        chime["at"] = double_point(chime["at"])
    return geo


def dumps(geo: dict) -> str:
    """Pretty JSON, but keep 2-element coordinate arrays and the grid inline so
    the file stays hand-editable in the same shape as before."""
    def enc(value, indent: int) -> str:
        pad = "  " * indent
        inner = "  " * (indent + 1)
        if isinstance(value, list):
            if all(isinstance(v, int) for v in value) and len(value) <= 2:
                return "[" + ", ".join(str(v) for v in value) + "]"
            if all(isinstance(v, str) for v in value):  # the grid
                rows = ",\n".join(f'{inner}{json.dumps(v)}' for v in value)
                return "[\n" + rows + f"\n{pad}]"
            items = ",\n".join(f"{inner}{enc(v, indent + 1)}" for v in value)
            return "[\n" + items + f"\n{pad}]"
        if isinstance(value, dict):
            items = ",\n".join(
                f"{inner}{json.dumps(k)}: {enc(v, indent + 1)}" for k, v in value.items()
            )
            return "{\n" + items + f"\n{pad}}}"
        return json.dumps(value)

    return enc(geo, 0) + "\n"


def main() -> int:
    files = sorted(ROOMS_DIR.glob("*.json"))
    if not files:
        print(f"no room files under {ROOMS_DIR}", file=sys.stderr)
        return 1
    for path in files:
        geo = json.loads(path.read_text(encoding="utf-8"))
        if geo.get("size_tiles", [0, 0])[0] >= 32:
            print(f"skip {path.name}: already migrated ({geo['size_tiles']})")
            continue
        migrated = migrate(geo)
        path.write_text(dumps(migrated), encoding="utf-8")
        print(f"migrated {path.name} -> {migrated['size_tiles']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
