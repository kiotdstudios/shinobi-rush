# Shinobi Rush — World Map Structure

This folder is the **canonical source for expandable world-map planning**. Each diagram renders directly in GitHub.

## Maps
1. **[MVP world map](MVP_WORLD_MAP.md)** — Primary implementation reference: Kōsen Village Gate, Forest A, Forest B, both forks, dead end, and potential shortcut between the forks.
2. **[Full-world expansion map](FULL_WORLD_MAP.md)** — Three eventual forest routes and neighboring village gate, with future connections distinguished from MVP paths.

## Diagram conventions
- Green nodes/solid edges: planned playable MVP layout.
- Gray/dashed edges: future expansion.
- Gold/dashed connection: potential shortcut **between Forest A's fork and Forest B's fork**.
- These diagrams are route topology only, not to scale.

## Change log
- **v0.2:** Fixed the shortcut endpoint (A fork ↔ B fork), removed the incorrect gate-return shortcut, and split MVP and full-world views for readability.
