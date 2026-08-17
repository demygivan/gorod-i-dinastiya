"""Validate building slot placement in coastal_river_layout.txt."""
from __future__ import annotations

import math
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from generate_coastal_layout import (  # noqa: E402
    FOOTPRINT,
    TOWN_HALL_FOOTPRINT,
    footprint_origin,
)

LAYOUT = Path(__file__).resolve().parents[1] / "data" / "city" / "coastal_river_layout.txt"
SLOT = set("SRDHGC")
ROAD = set("#=")
WATER = set("~")


def _as_grid(rows: list[list[str]]) -> list[list[str]]:
    return [list(row) for row in rows]


def _rect_for(grid: list[list[str]], x: int, y: int, ch: str) -> tuple[int, int, int, int] | None:
    if ch == "H":
        half = TOWN_HALL_FOOTPRINT // 2
        return x - half, y - half, TOWN_HALL_FOOTPRINT, TOWN_HALL_FOOTPRINT
    if ch == "G":
        return x, y, 1, 1
    origin = footprint_origin(grid, x, y, FOOTPRINT)
    if origin is None:
        return None
    return origin[0], origin[1], FOOTPRINT, FOOTPRINT


def _cells(ox: int, oy: int, w: int, h: int) -> list[tuple[int, int]]:
    return [(ox + i, oy + j) for j in range(h) for i in range(w)]


def main() -> None:
    rows = [list(line.rstrip("\n")) for line in LAYOUT.read_text(encoding="utf-8").splitlines()]
    height = len(rows)
    width = max(len(r) for r in rows)
    for row in rows:
        while len(row) < width:
            row.append(" ")
    grid = _as_grid(rows)

    slots: list[tuple[int, int, str]] = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in SLOT:
                slots.append((x, y, ch))

    print(f"Map: {width}x{height}")
    print(f"Slots total: {len(slots)}")
    print("By type:", dict(Counter(ch for *_, ch in slots)))

    close_pairs: list[tuple[float, tuple, tuple]] = []
    for i, a in enumerate(slots):
        for b in slots[i + 1 :]:
            d = math.hypot(b[0] - a[0], b[1] - a[1])
            if d < 2.0:
                close_pairs.append((d, a, b))
    print(f"\nAnchor pairs closer than 2 tiles: {len(close_pairs)}")
    for d, a, b in sorted(close_pairs)[:20]:
        print(f"  d={d:.2f}: {a} <-> {b}")
    if len(close_pairs) > 20:
        print(f"  ... {len(close_pairs) - 20} more")

    rects: dict[tuple[int, int, str], tuple[int, int, int, int]] = {}
    missing: list[tuple[int, int, str]] = []
    for slot in slots:
        x, y, ch = slot
        rect = _rect_for(grid, x, y, ch)
        if rect is None:
            missing.append(slot)
            continue
        rects[slot] = rect
    print(f"\nSlots without a land footprint: {len(missing)}")
    for s in missing:
        print(f"  {s}")

    overlap_pairs: list[tuple[tuple, tuple]] = []
    items = list(rects.items())
    for i, (a, ra) in enumerate(items):
        a_cells = set(_cells(*ra))
        for b, rb in items[i + 1 :]:
            if a_cells & set(_cells(*rb)):
                overlap_pairs.append((a, b))
    print(f"\nFootprint overlaps: {len(overlap_pairs)}")
    for a, b in overlap_pairs:
        print(f"  {a} <-> {b}")

    spill: list[tuple[tuple, str, tuple[int, int]]] = []
    for slot, rect in rects.items():
        x, y, ch = slot
        if ch in "HG":
            continue
        for cx, cy in _cells(*rect):
            if not (0 <= cx < width and 0 <= cy < height):
                spill.append((slot, "oob", (cx, cy)))
                continue
            cell = rows[cy][cx]
            if cell in WATER:
                spill.append((slot, "water", (cx, cy)))
            elif cell in ROAD:
                spill.append((slot, "road", (cx, cy)))
    print(f"\nFootprints spilling onto water/road: {len(spill)}")
    for item in spill[:40]:
        print(f"  {item}")

    on_bad = [((x, y, ch), "on_road") for x, y, ch in slots if rows[y][x] in ROAD]
    on_bad += [((x, y, ch), "on_water") for x, y, ch in slots if rows[y][x] in WATER]
    print(f"\nSlots on road/water: {len(on_bad)}")
    for item in on_bad:
        print(f"  {item}")

    no_road_adjacent: list[tuple[int, int, str]] = []
    for x, y, ch in slots:
        if ch in "HG":
            continue
        found = any(
            0 <= x + dx < width
            and 0 <= y + dy < height
            and rows[y + dy][x + dx] in ROAD
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))
        )
        if not found:
            no_road_adjacent.append((x, y, ch))
    print(f"\nSlots not adjacent to a road: {len(no_road_adjacent)}")
    for s in no_road_adjacent:
        print(f"  {s}")

    wall_corners = [(28, 16), (73, 16), (28, 51), (73, 51)]
    print("\nWall corners:")
    for x, y in wall_corners:
        print(f"  ({x},{y}) = {rows[y][x]!r}")

    buildable = sum(1 for row in rows for ch in row if ch in ".SRD")
    print(f"\nBuildable-ish cells (. S R D): {buildable}")
    print(f"Slot density: {len(slots)} slots / {width * height} cells = {100 * len(slots) / (width * height):.1f}%")


if __name__ == "__main__":
    main()
