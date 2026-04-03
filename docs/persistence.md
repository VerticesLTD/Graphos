# Persistence System

Graphos saves your work automatically, like Excalidraw. No manual save required.

---

## How It Works

Two save tiers — identical to Excalidraw's approach:

1. **Auto-save** — any meaningful change (add/delete vertex, move, color, zoom, pan, grid toggle, strategy switch) starts a 2-second quiet timer. When the timer fires, the scene is written to `user://autosave.graphos`. On next launch, this file is restored silently.
2. **Explicit file I/O** — named `.graphos` files via keyboard shortcuts. Same JSON format as auto-save.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `Ctrl+S` | Save to current file (falls back to autosave path) |
| `Ctrl+Shift+S` | Save As — always opens a file dialog |
| `Ctrl+O` | Open — load a `.graphos` file |

---

## File Format (`.graphos`)

Plain JSON, human-readable and diff-friendly:

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

`format_version: 1` preset files (the bundled graph presets) load without `app_state` — missing fields are filled with safe defaults.

---

## What Gets Saved

| State | Saved |
|---|---|
| Vertices (id, position, color) | Yes |
| Edges (endpoints, strategy, weight, color) | Yes |
| Next vertex ID counter | Yes |
| Active strategy (directed / undirected) | Yes |
| Weighted mode | Yes |
| Grid visibility | Yes |
| Camera position | Yes |
| Camera zoom | Yes |
| Current tool mode | No — resets to Selection on load |
| Algorithm player state | No — session only |
| Undo / redo history | No — cleared on load |

---

## Code Structure

```
core/persistence/
  graph_serializer.gd      # Graph ↔ Dictionary  (pure, no I/O)
  app_state_serializer.gd  # Camera/grid/strategy ↔ Dictionary  (pure, no I/O)
  document_io.gd           # Combines both; reads/writes .graphos JSON files
  auto_save_service.gd     # Debounced Node: emits save_requested after quiet period

scenes/main/
  persistence_manager.gd   # Wires signals, keyboard shortcuts, startup restore
```

### Design principles

- **Single responsibility** — each module does one thing. `GraphSerializer` knows nothing about files; `DocumentIO` knows nothing about the scene tree.
- **Reusable** — `GraphSerializer` and `AppStateSerializer` are pure static classes. Use them from tests, export tools, or clipboard code without pulling in any I/O.
- **Migration-safe** — `AppStateSerializer.from_dictionary()` fills in defaults for every field, so old documents always load cleanly.
- **Algorithm-safe** — `CommandManager.state_changed` only fires for `add_to_history` commands, so algorithm playback steps never trigger an auto-save.

### Signal flow

```
CommandManager.state_changed  ──┐
Camera.view_changed            ──┤──► AutoSaveService.mark_dirty() ──► [2s timer] ──► save
Globals.strategy_changed       ──┤
Globals.weighted_mode_changed  ──┤
PopupMenu.toggle_grid_requested─┘
```

---

## Autosave File Location

| Platform | Path |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/Graphos/autosave.graphos` |
| Windows | `%APPDATA%\Godot\app_userdata\Graphos\autosave.graphos` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Graphos/autosave.graphos` |
| Web export | Browser IndexedDB (handled automatically by Godot) |
