<div align="center">

<img src="assets/logo/SplashLogo.png" alt="Graphos Logo" width="160"/>

# Graphos

**Interactive graph editor and algorithm visualizer built with Godot 4**

Draw graphs. Run algorithms. Watch them unfold — step by step.

<br/>

[![Live Demo](https://img.shields.io/badge/Try%20it%20live-%E2%86%92-6c63ff?style=for-the-badge&logoColor=white)](https://verticesltd.github.io/Graphos/)
[![Godot Engine](https://img.shields.io/badge/Godot-4.6-blue?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript-blue?style=for-the-badge)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<br/>

<a href="https://verticesltd.github.io/Graphos/" target="_blank" rel="noopener noreferrer">
  <strong>▶ &nbsp;Open the Live Demo</strong>
</a>

</div>

---

## What is Graphos?

Graphos is a **browser-based graph editor and algorithm visualizer** — the kind of tool you wish existed when you were first learning about BFS, Dijkstra, or Kruskal in a data structures course.

You build a graph by hand — place vertices, draw edges, flip on weighted mode — then hit run and watch the algorithm execute on *your actual graph*, with a synchronized pseudocode panel highlighting each step as it happens. Scrub backward and forward through time. See exactly why the algorithm made each choice.

No installation. No account. No friction. It just works in the browser.

---

## Features

### Graph Editing
- Place **vertices** anywhere on an infinite math grid
- Connect them with **directed** or **undirected** edges
- Enable **weighted mode** to assign numeric costs to edges
- **Pan**, **zoom**, and navigate freely — the canvas is infinite
- **Color** individual vertices and edges for clarity
- **Select** regions with a drag rectangle and move, delete, or recolor them at once
- **Preset graphs** to jump-start your session

### Algorithm Visualization
- Algorithms run on your real, live graph — not a simulation on dummy data
- A **step timeline** records every visual change the algorithm makes
- **Scrub forward and backward** through every step
- **Auto-play** with a play/pause toggle
- A **pseudocode panel** highlights the exact line that corresponds to the current step
- Graceful handling of **disconnected components** with informative notifications

### Editing Quality of Life
- Full **undo / redo** via a command history — every structural and visual change is reversible
- **Cut, copy, and paste** graph selections
- **Auto-save** — your work is restored automatically when you return, no manual save needed
- **Save / load** named `.graphos` files (plain JSON, human-readable)
- **Share** your graph via a URL — encode the full graph state into a shareable link

---

## Algorithms

| Algorithm | Type | Notes |
|---|---|---|
| **BFS** | Traversal | Breadth-first from a chosen start vertex |
| **DFS** | Traversal | Depth-first from a chosen start vertex |
| **Dijkstra** | Shortest Path | Single-source shortest paths (non-negative weights) |
| **Prim** | Minimum Spanning Tree | Builds MST from a start vertex within its component |
| **Kruskal** | Minimum Spanning Forest | Builds MSF across all components using union-find |

---

## Keyboard Shortcuts

### General

| Action | Shortcut |
|---|---|
| Undo | `Ctrl` + `Z` |
| Redo | `Ctrl` + `Y` |
| Copy | `Ctrl` + `C` |
| Paste | `Ctrl` + `V` |
| Cut | `Ctrl` + `X` |
| Delete selection | `Delete` or `Backspace` |

### Graph Creation

| Action | Shortcut |
|---|---|
| Toggle weighted edges | `W` *(in create mode)* |
| Toggle directed edges | `D` *(in create mode)* |
| Run algorithm on selected vertex | `R` *(in algorithm mode)* |

### Algorithm Playback

| Action | Shortcut |
|---|---|
| Step backward | `←` |
| Step forward | `→` |
| Toggle auto-play | `Space` or `Enter` |

### File

| Action | Shortcut |
|---|---|
| Save | `Ctrl` + `S` |
| Save As | `Ctrl` + `Shift` + `S` |
| Open | `Ctrl` + `O` |

---

## File Format

Graphos saves graphs as plain `.graphos` files — human-readable JSON that you can diff, version, and edit by hand:

```json
{
  "format_version": 2,
  "next_vertex_id": 12,
  "vertices": [
    { "id": 0, "pos": [120.0, 80.0], "color": [0.118, 0.118, 0.180, 1.0] }
  ],
  "edges": [
    { "from": 0, "to": 1, "strategy": "undirected", "weighted": false, "weight": 1.0, "color": [0.286, 0.314, 0.337, 1.0] }
  ],
  "app_state": {
    "camera_position": [0.0, 0.0],
    "camera_zoom": 1.0,
    "grid_enabled": false,
    "active_strategy": "undirected",
    "is_weighted_mode": false
  }
}
```

Autosave files are written to:

| Platform | Location |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/Graphos/autosave.graphos` |
| Windows | `%APPDATA%\Godot\app_userdata\Graphos\autosave.graphos` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Graphos/autosave.graphos` |
| Web | Browser IndexedDB (managed automatically by Godot) |

---

## Tech Stack

- **[Godot Engine](https://godotengine.org/) 4.6** — game engine powering the editor
- **GDScript** — all game logic, UI, and algorithm implementations
- **Web export** — deployed to GitHub Pages via Godot's HTML5 export preset

---

## Running from Source

**Prerequisites:** [Godot 4.6](https://godotengine.org/download) (standard, not Mono)

```bash
git clone https://github.com/verticesltd/Graphos.git
cd Graphos
```

Then open Godot, click **Import**, select the cloned folder (or open `project.godot` directly), and press **F5** to run.

### Web Build

To reproduce the web export:

1. Open the project in Godot
2. Go to **Project → Export**
3. Select the **Web** preset
4. Click **Export Project** and deploy the output to your static host

> The live demo at [verticesltd.github.io/Graphos](https://verticesltd.github.io/Graphos/) is built and deployed this way via GitHub Pages.

---

## Project Structure

```
graphos/
├── algorithms/
│   ├── logic/          # BFS, DFS, Dijkstra, Prim, Kruskal implementations
│   └── pseudo_code/    # Pseudocode definitions per algorithm
├── commands/           # Command pattern — every undoable action lives here
│   ├── data/           # Color, weight, and property mutations
│   ├── structure/      # Add / delete vertex and edge commands
│   ├── clipboard/      # Copy, cut, paste commands
│   └── visuals/        # Visual-only commands (algorithm highlights)
├── controller/         # Input handling, mouse actions, clipboard, animation
├── core/               # Pure data: Vertex, Edge, serialization, sharing
├── globals/            # Autoloaded singletons (state, UI signals, logger)
├── scenes/             # All Godot scenes and their attached scripts
│   ├── main/           # Root scene, persistence manager, share manager
│   ├── algorithm_player/ # Playback controls UI
│   ├── pseudo_visualizer/ # Pseudocode panel
│   ├── tool_bar/       # Toolbar and tool mode switching
│   ├── popup_menu/     # Right-click context menus
│   ├── presets/        # Preset graph picker and thumbnails
│   └── sharing/        # URL-based share panel
└── assets/
    ├── logo/           # App logo / splash
    ├── icons/          # Toolbar and UI icons
    └── fonts/          # Typography
```

---

## Architecture Notes

Graphos is built around a few core ideas:

**Command pattern for everything undoable.** Every structural and visual change — adding a vertex, changing an edge color, running an algorithm step — is encapsulated in a `BaseCommand` with `execute()` and `undo()`. The `CommandManager` owns the history stack.

**Algorithm timeline.** When you run an algorithm, it doesn't mutate the graph directly — it records a sequence of `VisualCommand` objects (color changes, edge highlights, vertex discoveries). The `AlgorithmPlayer` then plays these back, which means you get scrubbing for free.

**Pure serialization.** `GraphSerializer` and `AppStateSerializer` are stateless static classes. They convert between graph data and dictionaries — no file I/O, no scene tree access. This keeps them testable and reusable from any context.

**Autosave without noise.** `AutoSaveService` uses a 2-second debounce timer. Algorithm playback steps intentionally do *not* trigger `state_changed`, so stepping through an algorithm never dirty-marks the document.

---

<div align="center">

Built with [Godot Engine](https://godotengine.org/) &nbsp;·&nbsp; <a href="https://verticesltd.github.io/Graphos/" target="_blank" rel="noopener noreferrer">Live Demo</a>

</div>
