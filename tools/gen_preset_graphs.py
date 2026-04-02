#!/usr/bin/env python3
"""One-shot generator for preset JSON (run from repo: python3 tools/gen_preset_graphs.py)."""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "presets", "data")

VC = [0.118, 0.118, 0.18, 1.0]
EC = [73 / 255, 80 / 255, 87 / 255, 1.0]
GRAPHOS_V = [
    [243 / 255, 146 / 255, 55 / 255, 1.0],
    [238 / 255, 150 / 255, 117 / 255, 1.0],
    [29 / 255, 151 / 255, 168 / 255, 1.0],
    [139 / 255, 162 / 255, 143 / 255, 1.0],
]


def dump(name: str, vertices: list, edges: list) -> None:
    doc = {"format_version": 1, "vertices": vertices, "edges": edges}
    path = os.path.join(OUT, f"{name}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("wrote", path, "V", len(vertices), "E", len(edges))


def graphos() -> None:
    """Graphos logo path (4 vertices, 3 edges)."""
    verts = [
        {"id": 0, "pos": [-63, -54], "color": GRAPHOS_V[0]},
        {"id": 1, "pos": [-9, 54], "color": GRAPHOS_V[1]},
        {"id": 2, "pos": [54, -9], "color": GRAPHOS_V[2]},
        {"id": 3, "pos": [0, -27], "color": GRAPHOS_V[3]},
    ]
    edges = []
    for a, b in [(0, 1), (1, 2), (2, 3)]:
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
        x, y = round(x * 16.0), round(y * 16.0)
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
    """16 vertices, 32 edges: nested regular octagons (flat top), outer/inner cycles, radials, cross-links."""
    r_out = 100.0
    r_in = 52.0
    verts = []
    for i in range(8):
        ang = -math.pi / 2 + i * 2 * math.pi / 8
        x, y = round(r_out * math.cos(ang)), round(r_out * math.sin(ang))
        verts.append({"id": i, "pos": [x, y], "color": VC})
    for i in range(8):
        ang = -math.pi / 2 + i * 2 * math.pi / 8
        x, y = round(r_in * math.cos(ang)), round(r_in * math.sin(ang))
        verts.append({"id": 8 + i, "pos": [x, y], "color": VC})
    edges: list = []
    seen: set = set()

    def add_edge(a: int, b: int) -> None:
        if a > b:
            a, b = b, a
        key = (a, b)
        if key in seen:
            return
        seen.add(key)
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

    for i in range(8):
        add_edge(i, (i + 1) % 8)
    for i in range(8):
        add_edge(8 + i, 8 + (i + 1) % 8)
    for i in range(8):
        add_edge(i, 8 + i)
        add_edge(i, 8 + (i + 4) % 8)
    assert len(edges) == 32
    dump("tesseract", verts, edges)


def mobius_ladder() -> None:
    """Möbius ladder n=4 → 8 vertices."""
    n = 8
    verts = []
    r = 102
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
    """Heawood = Levi graph of Fano plane; laid out on one circle along a Hamiltonian cycle."""
    lines = [
        (7, 0, 1, 3),
        (8, 1, 2, 4),
        (9, 2, 3, 5),
        (10, 3, 4, 6),
        (11, 4, 5, 0),
        (12, 5, 6, 1),
        (13, 6, 0, 2),
    ]
    edges: list = []
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
    # Hamiltonian cycle order keeps most edges near the hull (fewer crossings than id order around the circle).
    cycle = [0, 11, 4, 8, 1, 12, 5, 9, 2, 13, 6, 10, 3, 7]
    pos_index = {vid: k for k, vid in enumerate(cycle)}
    r = 128.0
    verts = []
    for vid in range(14):
        k = pos_index[vid]
        ang = -math.pi / 2 + k * 2 * math.pi / 14
        x, y = round(r * math.cos(ang)), round(r * math.sin(ang))
        verts.append({"id": vid, "pos": [x, y], "color": VC})
    dump("heawood", verts, edges)


def k33() -> None:
    """K3,3 utility graph — wide rungs, clear ladder between the two parts."""
    A = [0, 1, 2]
    B = [3, 4, 5]
    x_left, x_right = -122.0, 122.0
    sep_y = 108.0
    verts = []
    for i in A:
        y = round((i - 1) * sep_y)
        verts.append({"id": i, "pos": [round(x_left), y], "color": VC})
    for j in B:
        y = round((j - 4) * sep_y)
        verts.append({"id": j, "pos": [round(x_right), y], "color": VC})
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


def flower_petal() -> None:
    """Flower-style graph: center v0, hex v1–v6, petals (v_i, u_i, w_i) with v0–w_i edges (19 V, 36 E)."""
    # ids: 0=center, 1–6 hex, 7–12 u_i, 13–18 w_i
    r_hex = 72.0
    r_u = 98.0
    r_w = 128.0
    verts = [{"id": 0, "pos": [0, 0], "color": VC}]
    for i in range(6):
        ang = -math.pi / 2 + i * 2 * math.pi / 6
        c, s = math.cos(ang), math.sin(ang)
        px, py = -s, c
        hx, hy = r_hex * c, r_hex * s
        verts.append({"id": 1 + i, "pos": [round(hx), round(hy)], "color": VC})
        ux, uy = r_u * c + 18 * px, r_u * s + 18 * py
        wx, wy = r_w * c, r_w * s
        verts.append({"id": 7 + i, "pos": [round(ux), round(uy)], "color": VC})
        verts.append({"id": 13 + i, "pos": [round(wx), round(wy)], "color": VC})
    raw: list = []
    for i in range(6):
        a, b = i + 1, (i + 1) % 6 + 1
        raw.append((min(a, b), max(a, b)))
    for k in range(1, 7):
        raw.append((0, k))
    for i in range(6):
        vi, ui, wi = 1 + i, 7 + i, 13 + i
        for a, b in [(vi, ui), (vi, wi), (ui, wi), (0, wi)]:
            raw.append((min(a, b), max(a, b)))
    edges = list({tuple(e) for e in raw})
    assert len(edges) == 36
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


def kneser_52() -> None:
    """KG(5,2) = Petersen graph: 10 vertices, 15 edges. Outer pentagon + inner pentagram + spokes."""
    r_out = 105.0
    r_in = 52.0
    twist = math.pi / 5
    verts = []
    for i in range(5):
        ang = -math.pi / 2 + i * 2 * math.pi / 5
        x, y = round(r_out * math.cos(ang)), round(r_out * math.sin(ang))
        verts.append({"id": i, "pos": [x, y], "color": VC})
    for i in range(5):
        ang = -math.pi / 2 + i * 2 * math.pi / 5 + twist
        x, y = round(r_in * math.cos(ang)), round(r_in * math.sin(ang))
        verts.append({"id": 5 + i, "pos": [x, y], "color": VC})
    edges: list = []
    seen: set = set()

    def add_edge(a: int, b: int) -> None:
        if a > b:
            a, b = b, a
        key = (a, b)
        if key in seen:
            return
        seen.add(key)
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

    for i in range(5):
        add_edge(i, (i + 1) % 5)
    for i in range(5):
        add_edge(5 + i, 5 + (i + 2) % 5)
    for i in range(5):
        add_edge(i, 5 + i)
    assert len(edges) == 15
    dump("kneser_52", verts, edges)


def cycle_12() -> None:
    """Simple cycle C₁₂ on a regular polygon."""
    n = 12
    r = 112.0
    verts = []
    edges: list = []
    for i in range(n):
        ang = -math.pi / 2 + i * 2 * math.pi / n
        x, y = round(r * math.cos(ang)), round(r * math.sin(ang))
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
    dump("cycle_12", verts, edges)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    graphos()
    heart()
    tesseract()
    mobius_ladder()
    heawood()
    k33()
    flower_petal()
    kneser_52()
    cycle_12()


if __name__ == "__main__":
    main()
