# Persistence System

Graphos saves your work automatically, like Excalidraw. No manual save required.

---

## How It Works

Two save tiers:

1. **Auto-save** — any meaningful change (add/delete vertex, move, color, zoom, pan, grid toggle, strategy switch) starts a 2-second quiet timer. When the timer fires, the active graph is written to its own file in `user://graphs/`. On next launch, the last opened graph is restored silently.
2. **Explicit file I/O** — named `.graphos` files via keyboard shortcuts (desktop only). Same JSON format.

---

## Multi-Graph Storage

Each graph has a **stable, unique ID** (12-character hex string, e.g. `a3f2b1c40e88`).

Graphs are stored as individual files:

```
user://graphs/
  <graphId>.graphos   ← one file per graph
  index.json          ← tracks lastOpenedGraphId
```

On startup the app:
1. Migrates a legacy `user://autosave.graphos` file (if it exists) into the new store.
2. Loads the graph referenced by `lastOpenedGraphId`.
3. Creates a new empty default graph if no graphs exist.

---

## Sharing via URL

Share a graph using a URL that includes both the graph ID and its data:

```
app.com/?graphId=a3f2b1c40e88#json=<compressed-graph>
```

After the recipient opens the link, the hash is cleared, leaving a clean bookmark:

```
app.com/?graphId=a3f2b1c40e88
```

The `graphId` is stable — it never changes when sharing or editing.

### Conflict Handling

If a recipient already has a local graph with the same `graphId`, a dialog is shown:

| Choice | Behaviour |
|---|---|
| **Keep my copy** | The locally stored graph is kept; the shared data is discarded. |
| **Replace from link** | The local file is overwritten with the shared graph. |
| **Import as new** | A fresh ID is generated for the shared graph; both copies are preserved. |

---

## Duplicating a graph

`PersistenceManager.save_as_new_graph()` generates a new graph ID, saves the current canvas under that ID, and makes it the active graph; the previous file is left unchanged. There is no button for this in the **Share** popup (Share is link-only). When you open a shared link that matches an existing ID, **Import as new** in the conflict dialog saves the link’s graph as a separate local copy instead.

---

## Keyboard Shortcuts (desktop only)

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
  "graph_id": "a3f2b1c40e88",
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

`graph_id` is an optional field — legacy files without it load cleanly; a new ID is assigned on first save.

`format_version: 1` preset files (the bundled graph presets) load without `app_state` — missing fields are filled with safe defaults.

---

## What Gets Saved

| State | Saved |
|---|---|
| Graph ID | Yes |
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
  graph_id_util.gd     # Random stable ID generation
  graph_store.gd       # Multi-graph file storage & index management
  graph_serializer.gd  # Graph ↔ Dictionary  (pure, no I/O)
  app_state_serializer.gd  # Camera/grid/strategy ↔ Dictionary  (pure, no I/O)
  document_io.gd       # Combines both; builds/reads .graphos JSON documents
  auto_save_service.gd # Debounced Node: emits save_requested after quiet period

core/sharing/
  share_encoder.gd     # Encodes/decodes the full graph as a compressed URL fragment

scenes/main/
  persistence_manager.gd  # Wires signals, startup restore, conflict dialog, save-as-new
  share_manager.gd        # URL parsing, conflict detection, browser URL management
```

### Signal flow

```
CommandManager.state_changed  ──┐
Camera.view_changed            ──┤──► AutoSaveService.mark_dirty() ──► [2s timer] ──► GraphStore.save(activeId, doc)
Globals.strategy_changed       ──┤
Globals.weighted_mode_changed  ──┤
PopupMenu.toggle_grid_requested─┘
```

---

## Storage Locations

| Platform | Path |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/Graphos/graphs/` |
| Windows | `%APPDATA%\Godot\app_userdata\Graphos\graphs\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Graphos/graphs/` |
| Web export | Browser IndexedDB (handled automatically by Godot) |
