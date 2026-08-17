"""Generate data/city/coastal_river_layout.txt — ASCII coastal city map."""
from __future__ import annotations

import math
from pathlib import Path

WIDTH = 110
HEIGHT = 72

GROUND = "."
ROAD = "#"
BRIDGE = "="
WATER = "~"
PLAZA = "P"
TOWN_HALL = "H"
COMMERCIAL = "S"
MARITIME = "D"
RESIDENTIAL = "R"
GATE = "G"
CEMETERY = "C"

ROAD_SET = {ROAD, BRIDGE}
SLOT_SET = {COMMERCIAL, RESIDENTIAL, MARITIME, TOWN_HALL, GATE, CEMETERY}
# Keep in sync with world/placed_building_view.gd FOOTPRINT_TILES / TOWN_HALL_FOOTPRINT_TILES.
FOOTPRINT = 2
TOWN_HALL_FOOTPRINT = 3
# Gap between buildings = FOOTPRINT * SLOT_GAP_RATIO land tiles (rounded). Visual inset in PlacedBuildingView.
SLOT_GAP_RATIO = 1.0 / 3.0
SLOT_GAP = round(FOOTPRINT * SLOT_GAP_RATIO)
# road + footprint + gap + buffer before the next street.
BLOCK = 1 + FOOTPRINT + max(1, SLOT_GAP) + 1

WALL = (28, 16, 73, 51)
TOWN_HALL_POS = (48, 31)
GATE_POS = (48, 16)
CEMETERY_POS = (9, 57)
PLAZA_RECT = (44, 27, 52, 35)
LAKE_CENTER = (13, 29)
LAKE_RX = 6
LAKE_RY = 6
RIVER_BASE_X = 86
RIVER_WIDTH = 4
RIVER_AMPLITUDE = 5
RIVER_WAVELENGTH = 22
RIVER_Y0 = 0
SEA_Y0 = 62
HARBOR_Y = 55
NORTH_ROAD_Y = 8
WEST_OUTER_X = 4
WEST_INNER_X = 23
WEST_NORTH_Y = 18
WEST_SOUTH_Y = 44


def grid_lines(center: int, wall0: int, wall1: int, step: int, min_margin: int = 2) -> tuple[int, ...]:
    """Street lines aligned to the town hall, staying off the walls."""
    lines: list[int] = []
    pos = center
    while pos - step > wall0:
        pos -= step
    while pos < wall1:
        if pos - wall0 >= min_margin and wall1 - pos >= min_margin:
            lines.append(pos)
        pos += step
    return tuple(lines)


INNER_XS = grid_lines(TOWN_HALL_POS[0], WALL[0], WALL[2], BLOCK)
INNER_YS = grid_lines(TOWN_HALL_POS[1], WALL[1], WALL[3], BLOCK)


def blank() -> list[list[str]]:
    return [[GROUND] * WIDTH for _ in range(HEIGHT)]


def in_bounds(x: int, y: int) -> bool:
    return 0 <= x < WIDTH and 0 <= y < HEIGHT


def set_cell(grid: list[list[str]], x: int, y: int, ch: str) -> None:
    if in_bounds(x, y):
        grid[y][x] = ch


def fill_rect(grid: list[list[str]], x0: int, y0: int, x1: int, y1: int, ch: str) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            set_cell(grid, x, y, ch)


def fill_ellipse(grid: list[list[str]], cx: int, cy: int, rx: int, ry: int, ch: str) -> None:
    rx = max(1, rx)
    ry = max(1, ry)
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            nx = (x - cx) / float(rx)
            ny = (y - cy) / float(ry)
            if nx * nx + ny * ny <= 1.0:
                set_cell(grid, x, y, ch)


def is_ground(ch: str) -> bool:
    return ch == GROUND


def is_inside_plaza(x: int, y: int) -> bool:
    x0, y0, x1, y1 = PLAZA_RECT
    return x0 <= x <= x1 and y0 <= y <= y1


def is_inside_walls(x: int, y: int) -> bool:
    wx0, wy0, wx1, wy1 = WALL
    return wx0 <= x <= wx1 and wy0 <= y <= wy1


def river_left_x(y: int) -> int:
    t = (y - RIVER_Y0) * 2.0 * math.pi / RIVER_WAVELENGTH
    offset = RIVER_AMPLITUDE * math.sin(t) + 2.4 * math.sin(t * 0.52 + 1.15)
    x = int(round(RIVER_BASE_X + offset))
    min_x = WALL[2] + 6
    max_x = WIDTH - RIVER_WIDTH - 12
    return max(min_x, min(max_x, x))


def farthest_river_right() -> int:
    right = 0
    prev_left: int | None = None
    for y in range(RIVER_Y0, SEA_Y0 + 1):
        left = river_left_x(y)
        right = max(right, left + RIVER_WIDTH - 1)
        if prev_left is not None:
            right = max(right, max(prev_left, left) + RIVER_WIDTH - 1)
        prev_left = left
    return right


def nearest_river_left() -> int:
    return min(river_left_x(y) for y in range(RIVER_Y0, SEA_Y0 + 1))


def east_roads() -> tuple[int, int]:
    far = farthest_river_right()
    east = min(max(far + 3, WALL[2] + BLOCK * 2), WIDTH - 10)
    east2 = min(east + BLOCK, WIDTH - 4)
    return east, east2


def road_neighbors(grid: list[list[str]], x: int, y: int) -> int:
    count = 0
    for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nx, ny = x + dx, y + dy
        if in_bounds(nx, ny) and grid[ny][nx] in ROAD_SET:
            count += 1
    return count


def classify_slot_kind(x: int, y: int) -> str:
    wx0, wy0, wx1, wy1 = WALL
    east_road, _east2 = east_roads()
    if y >= HARBOR_Y and 22 <= x <= wx1:
        return MARITIME
    if wx1 < x < east_road:
        return COMMERCIAL
    if is_inside_walls(x, y):
        if abs(x - TOWN_HALL_POS[0]) <= 8 and abs(y - TOWN_HALL_POS[1]) <= 6:
            return COMMERCIAL
        if wy0 + 4 <= y <= wy1 - 4:
            return COMMERCIAL
        return RESIDENTIAL
    if x <= wx0 + 2 and y >= wy1 - 2:
        return RESIDENTIAL
    if y <= wy0 + 2:
        return RESIDENTIAL
    return RESIDENTIAL


def is_road(grid: list[list[str]], x: int, y: int) -> bool:
    return in_bounds(x, y) and grid[y][x] in ROAD_SET


def footprint_origin(grid: list[list[str]], x: int, y: int, size: int = FOOTPRINT) -> tuple[int, int] | None:
    """Anchor (x, y) is the road-adjacent cell; plot grows inland as a size×size square."""
    grow_x = -1 if is_road(grid, x + 1, y) and not is_road(grid, x - 1, y) else 1
    grow_y = -1 if is_road(grid, x, y + 1) and not is_road(grid, x, y - 1) else 1

    def origin_for(gx: int, gy: int) -> tuple[int, int]:
        ox = x if gx > 0 else x - (size - 1)
        oy = y if gy > 0 else y - (size - 1)
        return ox, oy

    def valid(ox: int, oy: int) -> bool:
        for j in range(size):
            for i in range(size):
                cx, cy = ox + i, oy + j
                if not in_bounds(cx, cy):
                    return False
                if (cx, cy) == (x, y):
                    continue
                if not is_ground(grid[cy][cx]):
                    return False
                if is_inside_plaza(cx, cy):
                    return False
                if max(abs(cx - TOWN_HALL_POS[0]), abs(cy - TOWN_HALL_POS[1])) <= TOWN_HALL_FOOTPRINT // 2:
                    return False
        return True

    for gx, gy in (
        (grow_x, grow_y),
        (-grow_x, grow_y),
        (grow_x, -grow_y),
        (-grow_x, -grow_y),
    ):
        ox, oy = origin_for(gx, gy)
        if valid(ox, oy):
            return ox, oy
    return None


def land_separation(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> tuple[int, int]:
    """Empty tiles between rects on each axis. -1 means the projections overlap."""
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    if ax + aw <= bx:
        dx = bx - (ax + aw)
    elif bx + bw <= ax:
        dx = ax - (bx + bw)
    else:
        dx = -1
    if ay + ah <= by:
        dy = by - (ay + ah)
    elif by + bh <= ay:
        dy = ay - (by + bh)
    else:
        dy = -1
    return dx, dy


def _overlap_range(a0: int, a1: int, b0: int, b1: int) -> tuple[int, int] | None:
    lo = max(a0, b0)
    hi = min(a1, b1)
    if lo < hi:
        return lo, hi
    return None


def strip_is_road(
    grid: list[list[str]],
    a: tuple[int, int, int, int],
    b: tuple[int, int, int, int],
) -> bool:
    """True if the gap between two plots is a street (buildings facing across a road)."""
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    dx, dy = land_separation(a, b)
    cells: list[tuple[int, int]] = []
    y_span = _overlap_range(ay, ay + ah, by, by + bh)
    x_span = _overlap_range(ax, ax + aw, bx, bx + bw)
    if dx >= 0 and y_span is not None:
        gap_x0 = min(ax + aw, bx + bw)
        gap_x1 = max(ax, bx)
        for y in range(y_span[0], y_span[1]):
            for x in range(gap_x0, gap_x1):
                cells.append((x, y))
    elif dy >= 0 and x_span is not None:
        gap_y0 = min(ay + ah, by + bh)
        gap_y1 = max(ay, by)
        for y in range(gap_y0, gap_y1):
            for x in range(x_span[0], x_span[1]):
                cells.append((x, y))
    if not cells:
        return False
    return all(in_bounds(x, y) and grid[y][x] in ROAD_SET for x, y in cells)


def slots_conflict(
    grid: list[list[str]],
    a: tuple[int, int, int, int],
    b: tuple[int, int, int, int],
    min_gap: int = SLOT_GAP,
) -> bool:
    """True if two footprints overlap or sit closer than min_gap land tiles."""
    dx, dy = land_separation(a, b)
    if dx < 0 and dy < 0:
        return True
    if min_gap <= 0:
        return False
    if dx >= min_gap or dy >= min_gap:
        return False
    if dx == 0 and dy == 0:
        return False
    if strip_is_road(grid, a, b):
        return False
    return True


def hall_rect() -> tuple[int, int, int, int]:
    hx, hy = TOWN_HALL_POS
    half = TOWN_HALL_FOOTPRINT // 2
    return hx - half, hy - half, TOWN_HALL_FOOTPRINT, TOWN_HALL_FOOTPRINT


def is_preferred_street_face(grid: list[list[str]], x: int, y: int) -> bool:
    """Keep the south and east faces of streets so the opposite side stays as yard."""
    return is_road(grid, x, y - 1) or is_road(grid, x - 1, y)


def can_place_slot(
    grid: list[list[str]],
    x: int,
    y: int,
    placed_rects: list[tuple[int, int, int, int]],
) -> bool:
    if not in_bounds(x, y):
        return False
    if not is_ground(grid[y][x]):
        return False
    if is_inside_plaza(x, y):
        return False
    if y < WALL[1]:
        return False
    if max(abs(x - TOWN_HALL_POS[0]), abs(y - TOWN_HALL_POS[1])) <= TOWN_HALL_FOOTPRINT // 2:
        return False
    neighbors = road_neighbors(grid, x, y)
    if neighbors == 0 or neighbors >= 3:
        return False
    if not is_preferred_street_face(grid, x, y):
        return False
    origin = footprint_origin(grid, x, y)
    if origin is None:
        return False
    rect = (origin[0], origin[1], FOOTPRINT, FOOTPRINT)
    return all(not slots_conflict(grid, rect, other) for other in placed_rects)


def place_fixed_slots(
    grid: list[list[str]],
    placed_rects: list[tuple[int, int, int, int]],
) -> None:
    hx, hy = TOWN_HALL_POS
    grid[hy][hx] = TOWN_HALL
    placed_rects.append(hall_rect())

    gx, gy = GATE_POS
    grid[gy][gx] = GATE
    placed_rects.append((gx, gy, 1, 1))

    cx, cy = CEMETERY_POS
    if not is_ground(grid[cy][cx]):
        raise ValueError(f"Cemetery slot blocked at ({cx}, {cy}) by {grid[cy][cx]!r}")
    origin = footprint_origin(grid, cx, cy)
    if origin is None:
        raise ValueError(f"Cemetery footprint does not fit at ({cx}, {cy})")
    grid[cy][cx] = CEMETERY
    placed_rects.append((origin[0], origin[1], FOOTPRINT, FOOTPRINT))


def place_slots_along_roads(grid: list[list[str]]) -> None:
    placed_rects: list[tuple[int, int, int, int]] = []
    place_fixed_slots(grid, placed_rects)

    candidates: list[tuple[int, int, str]] = []
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if not can_place_slot(grid, x, y, placed_rects):
                continue
            kind = classify_slot_kind(x, y)
            candidates.append((x, y, kind))

    order = {COMMERCIAL: 0, MARITIME: 1, RESIDENTIAL: 2}
    candidates.sort(key=lambda item: (order.get(item[2], 9), item[1], item[0]))
    for x, y, kind in candidates:
        if not can_place_slot(grid, x, y, placed_rects):
            continue
        origin = footprint_origin(grid, x, y)
        if origin is None:
            continue
        grid[y][x] = kind
        placed_rects.append((origin[0], origin[1], FOOTPRINT, FOOTPRINT))


def draw_water(grid: list[list[str]]) -> None:
    for y in range(SEA_Y0, HEIGHT):
        for x in range(WIDTH):
            grid[y][x] = WATER

    prev_left: int | None = None
    for y in range(RIVER_Y0, SEA_Y0 + 1):
        left = river_left_x(y)
        for dx in range(RIVER_WIDTH):
            set_cell(grid, left + dx, y, WATER)
        if prev_left is not None and prev_left != left:
            lo = min(prev_left, left)
            hi = max(prev_left, left) + RIVER_WIDTH
            for x in range(lo, hi):
                set_cell(grid, x, y, WATER)
                set_cell(grid, x, y - 1, WATER)
        prev_left = left

    # River mouth widens west into the harbor, not east over the far bank.
    for y in range(HARBOR_Y - 4, SEA_Y0 + 1):
        left = river_left_x(y)
        for x in range(left - 8, left + RIVER_WIDTH):
            set_cell(grid, x, y, WATER)

    fill_ellipse(grid, LAKE_CENTER[0], LAKE_CENTER[1], LAKE_RX, LAKE_RY, WATER)


def draw_road_hline(grid: list[list[str]], y: int, x0: int, x1: int) -> None:
    lo, hi = (x0, x1) if x0 <= x1 else (x1, x0)
    for x in range(lo, hi + 1):
        if not in_bounds(x, y):
            continue
        set_cell(grid, x, y, BRIDGE if grid[y][x] == WATER else ROAD)


def draw_road_vline(grid: list[list[str]], x: int, y0: int, y1: int) -> None:
    lo, hi = (y0, y1) if y0 <= y1 else (y1, y0)
    for y in range(lo, hi + 1):
        if not in_bounds(x, y):
            continue
        set_cell(grid, x, y, BRIDGE if grid[y][x] == WATER else ROAD)


def draw_roads(grid: list[list[str]]) -> None:
    wx0, wy0, wx1, wy1 = WALL
    east_road, east_road_2 = east_roads()
    river_min = nearest_river_left()
    riverside = wx1 + BLOCK
    if riverside >= river_min:
        riverside = max(wx1 + 2, river_min - 3)

    # North approaches — one cross-street, then avenues down to the wall.
    for x in INNER_XS:
        draw_road_vline(grid, x, 0, wy0)
    draw_road_hline(grid, NORTH_ROAD_Y, WEST_OUTER_X, wx1)

    # West loop around the lake, tied into the west wall.
    draw_road_hline(grid, WEST_NORTH_Y, WEST_OUTER_X, wx0)
    draw_road_vline(grid, WEST_OUTER_X, NORTH_ROAD_Y, WEST_SOUTH_Y)
    draw_road_hline(grid, WEST_SOUTH_Y, WEST_OUTER_X, wx0)
    draw_road_vline(grid, WEST_INNER_X, wy0, WEST_SOUTH_Y)

    # City walls and inner grid (BLOCK spacing).
    draw_road_hline(grid, wy0, wx0, wx1)
    draw_road_hline(grid, wy1, wx0, wx1)
    draw_road_vline(grid, wx0, wy0, wy1)
    draw_road_vline(grid, wx1, wy0, wy1)

    for y in INNER_YS:
        draw_road_hline(grid, y, wx0 + 1, wx1 - 1)
    for x in INNER_XS:
        draw_road_vline(grid, x, wy0 + 1, wy1 - 1)

    px0, py0, px1, py1 = PLAZA_RECT
    fill_rect(grid, px0, py0, px1, py1, PLAZA)
    draw_road_hline(grid, TOWN_HALL_POS[1], wx0 + 1, wx1 - 1)
    draw_road_vline(grid, TOWN_HALL_POS[0], wy0 + 1, wy1 - 1)

    # South wall → harbor → docks.
    draw_road_hline(grid, HARBOR_Y, 18, river_left_x(HARBOR_Y) - 1)
    for x in (wx0, TOWN_HALL_POS[0], INNER_XS[-2] if len(INNER_XS) >= 2 else wx1 - BLOCK):
        draw_road_vline(grid, x, wy1, HARBOR_Y + 4)
    draw_road_vline(grid, TOWN_HALL_POS[0], wy1, HARBOR_Y + 6)
    draw_road_hline(grid, HARBOR_Y + 4, 18, wx1)

    # Cemetery at bottom-left, connected to the west loop and harbor.
    draw_road_vline(grid, 8, 44, 61)
    draw_road_hline(grid, 52, 6, wx0)
    draw_road_hline(grid, 58, 6, 22)

    # East district between wall and river, then bridges across the meander.
    draw_road_vline(grid, riverside, wy0, wy1)
    bridge_ys = [y for y in INNER_YS if y not in (TOWN_HALL_POS[1],)]
    if len(bridge_ys) >= 2:
        for y in (bridge_ys[0], bridge_ys[len(bridge_ys) // 2], bridge_ys[-1]):
            draw_road_hline(grid, y, wx1, east_road_2)
    else:
        draw_road_hline(grid, wy0 + BLOCK, wx1, east_road_2)
        draw_road_hline(grid, wy1 - BLOCK, wx1, east_road_2)
    draw_road_vline(grid, east_road, 12, HARBOR_Y)
    draw_road_vline(grid, east_road_2, 12, wy1)
    draw_road_hline(grid, wy1 - BLOCK, east_road, east_road_2)

    grid[GATE_POS[1]][GATE_POS[0]] = GATE


def build() -> list[list[str]]:
    grid = blank()
    draw_water(grid)
    draw_roads(grid)
    place_slots_along_roads(grid)

    wx0, wy0, wx1, wy1 = WALL
    for cx, cy in ((wx0, wy0), (wx1, wy0), (wx0, wy1), (wx1, wy1)):
        grid[cy][cx] = ROAD
    grid[GATE_POS[1]][GATE_POS[0]] = GATE
    grid[TOWN_HALL_POS[1]][TOWN_HALL_POS[0]] = TOWN_HALL
    grid[CEMETERY_POS[1]][CEMETERY_POS[0]] = CEMETERY
    return grid


def main() -> None:
    grid = build()
    lines = ["".join(row).rstrip() for row in grid]
    while lines and not lines[-1]:
        lines.pop()

    out = Path(__file__).resolve().parents[1] / "data" / "city" / "coastal_river_layout.txt"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    slots = sum(row.count(ch) for row in lines for ch in SLOT_SET)
    by_kind = {ch: sum(row.count(ch) for row in lines) for ch in "SRDHGC"}
    print(f"Wrote {out} ({len(lines[0]) if lines else 0}x{len(lines)}), slots={slots} {by_kind}")
    print(f"Inner streets xs={INNER_XS} ys={INNER_YS}")
    print(f"River x-range ~{nearest_river_left()}-{farthest_river_right()}, east roads={east_roads()}")


if __name__ == "__main__":
    main()
