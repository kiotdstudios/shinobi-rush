# Kōsen Forest — World Map Structure

**Version:** 0.1 · **Status:** evolving world topology · **MVP:** Kōsen home gate + two forest routes

This folder is the canonical, version-controlled location for world-map planning. GitHub renders the diagram below automatically, so we can review and revise the structure together without uploading a new screenshot each time.

## World structure — planned routes

```mermaid
flowchart TD
    G["KŌSEN VILLAGE GATE<br/>Player start"]
    G --> A["FOREST PATH A<br/>MVP"]
    G --> B["FOREST PATH B<br/>MVP"]
    G -.-> C["FOREST PATH C<br/>Future expansion"]
    A --> AF{"Path A fork"}
    AF --> AD["Dead-end clearing<br/>Optional reward / encounter"]
    AF --> AS["Hidden side passage"]
    B --> BF{"Path B fork"}
    BF --> BC["Connecting forest trail"]
    BF -.-> NG["Neighboring village gate<br/>Future expansion"]
    BC --- AS
    AD -.-> SC["Potential shortcut<br/>unlockable return route"]
    SC -.-> G
    classDef start fill:#30473d,color:#ffffff,stroke:#86b99a,stroke-width:2px;
    classDef mvp fill:#243b32,color:#ffffff,stroke:#7dab8c;
    classDef future fill:#3d4046,color:#ffffff,stroke:#a2a7ae,stroke-dasharray:5 4;
    classDef shortcut fill:#66502b,color:#ffffff,stroke:#e0b86e,stroke-dasharray:5 4;
    class G start;
    class A,B,AF,BF,AD,AS,BC mvp;
    class C,NG future;
    class SC shortcut;
```

### Reading the diagram
- **Solid connections:** established forest paths and the interconnecting branch between A and B.
- **Dashed gray connections:** planned expansion beyond the MVP, including Path C and the neighboring village gate.
- **Gold dashed shortcut:** **potential** unlockable return route from the dead-end clearing toward the Kōsen gate. This is a design proposal, not yet finalized in-world geography.

### MVP boundaries
- Implement Kōsen Village gate as the player spawn and starting landmark.
- Implement **two** connected forest routes (A and B), including their forks, with the inter-path connection as the first navigation test.
- Reserve the third forest route and neighboring village approach for later; block access in a natural, intentional way.
- Keep the basic bandit, heavy bandit, and one boss. Exact enemy placement, checkpoint positions, and boss arena are TBD.
- Preserve navigation via landmarks, discoverable detours, and backtracking.

### Revision workflow
1. Update this Mermaid graph when a path, fork, shortcut, checkpoint, or region is added.
2. Add a short note to **Revision history** below.
3. Do not silently turn proposed dashed connections into confirmed routes.
4. Keep future maps under `world/maps/` and link them from this index.

### Revision history
- **v0.1:** Kōsen gate start; three planned forest paths; two-path MVP; dead-end fork, inter-path connection, future neighboring village gate; proposed unlockable shortcut returning toward home gate.
