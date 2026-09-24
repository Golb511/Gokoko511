"""Map design helper for hand-authored stages.

Validates road geometry and proposes tower-slot positions with high road
coverage. The designer copies the chosen slots into data/regions.json; the game
never generates slots for hand-authored maps at runtime.
Usage: python3 tools/design/map_tool.py <stage_id> [--propose]
"""
import json, math, sys

def densify(path, step=1.0):
    out = []
    for i in range(len(path) - 1):
        (x0, z0), (x1, z1) = path[i], path[i + 1]
        n = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, i))
    out.append((path[-1][0], path[-1][1], len(path) - 2))
    return out

def dist_to_path(p, path):
    best = 1e9
    for i in range(len(path) - 1):
        (ax, az), (bx, bz) = path[i], path[i + 1]
        dx, dz = bx - ax, bz - az
        L = dx * dx + dz * dz
        t = max(0, min(1, ((p[0] - ax) * dx + (p[1] - az) * dz) / L)) if L else 0
        best = min(best, math.hypot(p[0] - ax - t * dx, p[1] - az - t * dz))
    return best

def load(stage):
    d = json.load(open("data/regions.json"))
    for r in d["regions"]:
        for s in r["stages"]:
            if s["id"] == stage:
                return s
    raise SystemExit("no stage " + stage)

def main():
    stage = sys.argv[1]
    s = load(stage)
    m = s["map"]
    ground = [p["points"] for p in m["paths"] if not p.get("air")]
    allp = [p["points"] for p in m["paths"]]
    # self separation
    for gi, path in enumerate(ground):
        worst = 99
        for (x, z, i) in densify(path):
            for j in range(len(path) - 1):
                if abs(j - i) > 1:
                    worst = min(worst, dist_to_path((x, z), path[j:j + 2]))
        print(f"path {gi}: self-separation {worst:.1f}")
    castle = m["castle"]
    slots = m.get("slots", [])
    # Region 3 obstacles: lava rivers, lava pools, basalt fields, vents, volcano.
    def blocked(c):
        for lr in m.get("lava_rivers", []):
            if dist_to_path(c, lr["points"]) < lr.get("width", 3.2) * 0.5 + 2.4: return True
        for o in m.get("lava", []) + m.get("basalt", []):
            if math.hypot(c[0] - o[0], c[1] - o[1]) < o[2] + 2.4: return True
        for v in m.get("vents", []):
            if math.hypot(c[0] - v["pos"][0], c[1] - v["pos"][1]) < v.get("radius", 1.9) + 2.8: return True
        if "volcano" in m:
            vp = m["volcano"]["pos"]
            if math.hypot(c[0] - vp[0], c[1] - vp[1]) < m["volcano"].get("radius", 7) + 2.2: return True
        return False
    for vv in m.get("vents", []):
        d = min(dist_to_path(vv["pos"], p) for p in ground)
        print(f"vent {vv['pos']} distance to road {d:.1f}")
    if "--propose" in sys.argv:
        cands = []
        for path in ground:
            pts = densify(path, 5.0)
            for idx, (x, z, i) in enumerate(pts[1:-1]):
                (ax, az), (bx, bz) = path[i], path[i + 1]
                L = math.hypot(bx - ax, bz - az) or 1
                nx, nz = -(bz - az) / L, (bx - ax) / L
                for sgn in (-1, 1):
                    cands.append((round(x + nx * 4.6 * sgn, 1), round(z + nz * 4.6 * sgn, 1)))
        def ok(c):
            if not (-37 < c[0] < 37 and -29 < c[1] < 27): return False
            if min(dist_to_path(c, p) for p in ground) < 3.8: return False
            if math.hypot(c[0] - castle[0], c[1] - castle[1]) < 9: return False
            for p in allp:
                if math.hypot(c[0] - p[0][0], c[1] - p[0][1]) < 6: return False
            for w in m.get("water", []):
                if math.hypot(c[0] - w[0], c[1] - w[1]) < w[2] + 2.2: return False
            for lm in m.get("landmarks", []):
                if math.hypot(c[0] - lm["pos"][0], c[1] - lm["pos"][1]) < lm.get("clear", 3.0) + 2.0: return False
            if blocked(c): return False
            return True
        def cover(c):
            return sum(1 for path in ground for (x, z, _) in densify(path) if math.hypot(x - c[0], z - c[1]) < 9)
        cands = sorted({c for c in cands if ok(c)}, key=lambda c: -cover(c))
        chosen = []
        for c in cands:
            if all(math.hypot(c[0] - o[0], c[1] - o[1]) >= 5.6 for o in chosen):
                chosen.append(c)
            if len(chosen) >= int(sys.argv[3]) if len(sys.argv) > 3 else len(chosen) >= 13:
                break
        print("proposed slots:", json.dumps([list(c) for c in chosen]))
        slots = [list(c) for c in chosen]
    # checks on authored slots
    for sl in slots:
        d = min(dist_to_path(sl, p) for p in ground)
        if d < 3.6: print("  SLOT TOO CLOSE TO ROAD", sl, round(d, 1))
        if blocked(sl): print("  SLOT ON OBSTACLE", sl)
    for a in range(len(slots)):
        for b in range(a + 1, len(slots)):
            if math.hypot(slots[a][0] - slots[b][0], slots[a][1] - slots[b][1]) < 5.0:
                print("  SLOTS OVERLAP", slots[a], slots[b])
    # ascii preview (x -40..40, z -32..30)
    W, H = 80, 31
    grid = [[" "] * W for _ in range(H)]
    def put(x, z, ch):
        cx, cz = int((x + 40) / 80 * (W - 1)), int((z + 32) / 62 * (H - 1))
        if 0 <= cx < W and 0 <= cz < H: grid[cz][cx] = ch
    for p in m["paths"]:
        for (x, z, _) in densify(p["points"], 0.8):
            put(x, z, "~" if p.get("air") else "#")
    for lr in m.get("lava_rivers", []):
        for (x, z, _) in densify(lr["points"], 0.8): put(x, z, "=")
    for o in m.get("lava", []): put(o[0], o[1], "@")
    for o in m.get("basalt", []): put(o[0], o[1], "B")
    for v in m.get("vents", []): put(v["pos"][0], v["pos"][1], "V")
    if "volcano" in m: put(m["volcano"]["pos"][0], m["volcano"]["pos"][1], "^")
    for p in m["paths"]:
        if not p.get("air"):
            for (x, z, _) in densify(p["points"], 0.8):
                for lr in m.get("lava_rivers", []):
                    if dist_to_path((x, z), lr["points"]) < lr.get("width", 3.2) * 0.5: put(x, z, "H")
    for lm in m.get("landmarks", []): put(lm["pos"][0], lm["pos"][1], "L")
    for sl in slots: put(sl[0], sl[1], "o")
    put(castle[0], castle[1], "C")
    print("\n".join("".join(r) for r in grid))

if __name__ == "__main__":
    main()
