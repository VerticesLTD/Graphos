# Graphos

**Interactive graph editor and algorithm visualizer** — draw vertices and edges on a grid, then watch classic graph algorithms run step by step with synchronized pseudocode and playback controls.

<p align="center">
  <a href="https://verticesltd.github.io/Graphos/"><strong>Open the live demo →</strong></a>
</p>

---

## What you can do

Build graphs by hand: place vertices, connect them with **directed** or **undirected** edges, and switch **weighted** mode when you need numeric costs. Pan across an infinite-style math grid, select regions of the graph, and use the toolbar to move between **selection**, **create**, **pan**, **algorithm**, and **eraser** modes.

When you run an algorithm, Graphos records a **timeline** of visual updates on the real graph. You can scrub forward and backward, or auto-play — with a **pseudocode panel** that highlights the line that matches the current step. Disconnected components are handled gracefully (with notifications for Prim, Kruskal, and reachability-based traversals).

Editing is built around a **command history**, so structural changes integrate cleanly with **undo** and **redo**.

## Algorithms

| Algorithm   | Notes |
|------------|--------|
| **BFS**    | Breadth-first traversal from a start vertex |
| **DFS**    | Depth-first traversal |
| **Dijkstra** | Shortest paths from a source (non-negative weights) |
| **Prim**   | Minimum spanning tree (connected component from start) |
| **Kruskal** | Minimum spanning forest across components |

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| Undo / Redo | `Ctrl` + `Z` / `Ctrl` + `Y` |
| Copy / Paste / Cut | `Ctrl` + `C` / `V` / `X` |
| Run algorithm (context-dependent) | `R` |
| Delete selection | `Delete` or `Backspace` |
| Toggle weighted edges (in create mode) | `W` |
| Toggle directed edges (in create mode) | `D` |
| Step algorithm backward / forward | `←` / `→` |
| Toggle algorithm auto-play | `Space` or `Enter` |

*Uses Godot’s built-in `ui_left`, `ui_right`, and `ui_accept` actions while an algorithm is active.*

## Tech stack

- **[Godot Engine](https://godotengine.org/)** 4.6 — **GDScript**
- **Web export** preset (`export/Graphos.html`) for the GitHub Pages build

## Running from source

1. Install [Godot 4.6](https://godotengine.org/download) (or matching 4.x).
2. Clone this repository and **Import** the project folder (or open `project.godot`).
3. Press **F5** to run the main scene.

To reproduce a web build, use the **Web** export preset in the editor and deploy the exported files to your static host (as on [GitHub Pages](https://verticesltd.github.io/Graphos/)).

---

<p align="center">
  <sub>Live site: <a href="https://verticesltd.github.io/Graphos/">https://verticesltd.github.io/Graphos/</a></sub>
</p>
