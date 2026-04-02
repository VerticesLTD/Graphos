#!/usr/bin/env python3
"""One-shot generator for preset JSON (run from repo: python3 tools/gen_preset_graphs.py)."""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "presets", "data")

VC = [0.118, 0.118, 0.18, 1.0]
EC = [0.29, 0.31, 0.34, 1.0]
V_BLUE = [0.263, 0.38, 0.933, 1.0]
V_TEAL = [0.024, 0.714, 0.627, 1.0]


def dump(name: str, vertices: list, edges: list) -> None:
    doc = {"format_version": 1, "vertices": vertices, "edges": edges}
    path = os.path.join(OUT, f"{name}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("wrote", path, "V", len(vertices), "E", len(edges))


def graphos() -> None:
    """4-cycle with brand-ish vertex accents (matches Graphos vibe)."""
    verts = [
        {"id": 0, "pos": [0, -85], "color": V_BLUE},
        {"id": 1, "pos": [85, 0], "color": VC},
        {"id": 2, "pos": [0, 85], "color": V_TEAL},
        {"id": 3, "pos": [-85, 0], "color": VC},
    ]
    edges = []
    for a, b in [(0, 1), (1, 2), (2, 3), (3, 0)]:
        edges.append(
            {
                "from": a,
                "to": b,
                "strategy": "undirected",
                "weighted": False,
                "weight": 1.0,
                "color": EC,
            }
        )
    dump("graphos", verts, edges)


def heart() -> None:
    """Heart outline as a cycle (pretty, symmetric)."""
    n = 28
    verts = []
    edges = []
    for i in range(n):
        t = 2 * math.pi * i / n
        # Heart curve (scaled)
        x = 16 * (math.sin(t) ** 3)
        y = -(
            13 * math.cos(t)
            - 5 * math.cos(2 * t)
            - 2 * math.cos(3 * t)
            - math.cos(4 * t)
        )
        x, y = round(x * 5.2), round(y * 5.2)
        verts.append({"id": i, "pos": [x, y], "color": VC})
    for i in range(n):
        a, b = i, (i + 1) % n
        if a > b:
            a, b = b, a
        edges.append(
            {
                "from": a,
                "to": b,
                "strategy": "undirected",
                "weighted": False,
                "weight": 1.0,
                "color": EC,
            }
        )
    dump("heart", verts, edges)


def tesseract() -> None:
    """4-cube Q4: 16 vertices as 4-bit strings, edges if Hamming distance 1."""
    verts = []
    for i in range(16):
        # 2D layout: Gray-code order on a circle-ish + radius by popcount
        bits = bin(i).count("1")
        ang = i / 16 * 2 * math.pi - math.pi / 2
        r = 38 + bits * 10
        x, y = round(44 + r * math.cos(ang)), round(44 + r * math.sin(ang))
        verts.append({"id": i, "pos": [x - 44, y - 44], "color": VC})
    seen = set()
    edges = []
    for u in range(16):
        for b in range(4):
            v = u ^ (1 << b)
            a, c = (u, v) if u < v else (v, u)
            key = (a, c)
            if key in seen:
                continue
            seen.add(key)
            edges.append(
                {
                    "from": a,
                    "to": c,
                    "strategy": "undirected",
                    "weighted": False,
                    "weight": 1.0,
                    "color": EC,
                }
            )
    dump("tesseract", verts, edges)


def mobius_ladder() -> None:
    """Möbius ladder n=4 → 8 vertices."""
    n = 8
    verts = []
    r = 95
    for i in range(n):
        ang = -math.pi / 2 + i * 2 * math.pi / n
        x, y = round(r * math.cos(ang)), round(r * math.sin(ang))
        verts.append({"id": i, "pos": [x, y], "color": VC})
    edges = []
    for i in range(n):
        a, b = i, (i + 1) % n
        if a > b:
            a, b = b, a
        edges.append(
            {
                "from": a,
                "to": b,
                "strategy": "undirected",
                "weighted": False,
                "weight": 1.0,
                "color": EC,
            }
        )
    # opposite rungs
    for i in range(n // 2):
        a, b = i, (i + n // 2) % n
        if a > b:
            a, b = b, a
        edges.append(
            {
                "from": a,
                "to": b,
                "strategy": "undirected",
                "weighted": False,
                "weight": 1.0,
                "color": EC,
            }
        )
    dump("mobius_ladder", verts, edges)


def heawood() -> None:
    """Heawood = Levi graph of Fano plane: points 0-6, lines 7-13."""
    lines = [
        (7, 0, 1, 3),
        (8, 1, 2, 4),
        (9, 2, 3, 5),
        (10, 3, 4, 6),
        (11, 4, 5, 0),
        (12, 5, 6, 1),
        (13, 6, 0, 2),
    ]
    verts = []
    for i in range(14):
        ang = -math.pi / 2 + i * 2 * math.pi / 14
        r = 108 if i < 7 else 62
        x, y = round(r * math.cos(ang)), round(r * math.sin(ang))
        verts.append({"id": i, "pos": [x, y], "color": VC})
    edges = []
    for L, p, q, r in lines:
        for u, v in [(L, p), (L, q), (L, r)]:
            a, b = (u, v) if u < v else (v, u)
            edges.append(
                {
                    "from": a,
                    "to": b,
                    "strategy": "undirected",
                    "weighted": False,
                    "weight": 1.0,
                    "color": EC,
                }
            )
    dump("heawood", verts, edges)


def k33() -> None:
    """K3,3 utility graph."""
    A = [0, 1, 2]
    B = [3, 4, 5]
    verts = []
    for i in A:
        x = -95
        y = round(-80 + 80 * i)
        verts.append({"id": i, "pos": [x, y], "color": VC})
    for j in B:
        x = 95
        y = round(-80 + 80 * (j - 3))
        verts.append({"id": j, "pos": [x, y], "color": VC})
    edges = []
    for a in A:
        for b in B:
            edges.append(
                {
                    "from": a,
                    "to": b,
                    "strategy": "undirected",
                    "weighted": False,
                    "weight": 1.0,
                    "color": EC,
                }
            )
    dump("k33", verts, edges)


def flower_snark_j5() -> None:
    """Wikipedia construction for J5 (n=5), 20 vertices, 30 edges."""
    # Stars i=1..5: Ai central, Bi,Ci,Di leaves. Vertex ids:
    # i=1..5 -> base = (i-1)*4, Ai=base, Bi=base+1, Ci=base+2, Di=base+3
    edges = []
    for i in range(5):
        base = i * 4
        A, B, C, D = base, base + 1, base + 2, base + 3
        for u, v in [(A, B), (A, C), (A, D)]:
            edges.append((min(u, v), max(u, v)))
    # B-cycle B1..B5: ids 1,5,9,13,17
    Bs = [1, 5, 9, 13, 17]
    for i in range(5):
        u, v = Bs[i], Bs[(i + 1) % 5]
        edges.append((min(u, v), max(u, v)))
    # 2n-cycle C1..C5 D1..D5: C=2,6,10,14,18 D=3,7,11,15,19
    order = [2, 6, 10, 14, 18, 3, 7, 11, 15, 19]
    for i in range(10):
        u, v = order[i], order[(i + 1) % 10]
        edges.append((min(u, v), max(u, v)))
    # unique
    edges = list(set(edges))
    assert len(edges) == 30
    verts = []
    for v in range(20):
        ang = -math.pi / 2 + (v / 20) * 2 * math.pi
        r = 118
        x, y = round(r * math.cos(ang)), round(r * math.sin(ang))
        verts.append({"id": v, "pos": [x, y], "color": VC})
    out_e = []
    for a, b in edges:
        out_e.append(
            {
                "from": a,
                "to": b,
                "strategy": "undirected",
                "weighted": False,
                "weight": 1.0,
                "color": EC,
            }
        )
    dump("flower_snark", verts, out_e)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    graphos()
    heart()
    tesseract()
    mobius_ladder()
    heawood()
    k33()
    flower_snark_j5()


if __name__ == "__main__":
    main()
