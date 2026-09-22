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
