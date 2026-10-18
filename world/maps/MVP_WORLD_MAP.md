# Kōsen Forest — MVP World Map

**Status:** Approved starting layout · **Scope:** Kōsen Gate + Forest A + Forest B

## MVP route diagram

```mermaid
flowchart TB
    G["KŌSEN VILLAGE GATE<br/>Player spawn"]
    G --> A["FOREST A<br/>Main trail"]
    G --> B["FOREST B<br/>Main trail"]
    A --> AF{"FOREST A FORK"}
    B --> BF{"FOREST B FORK"}
    AF --> D["Dead-end clearing<br/>Optional discovery"]
    AF <-->|"Potential unlockable shortcut"| BF

    classDef start fill:#30473d,color:#fff,stroke:#89b99a,stroke-width:2px;
    classDef forest fill:#243b32,color:#fff,stroke:#7dab8c;
    classDef fork fill:#355647,color:#fff,stroke:#9bc7a7;
    classDef optional fill:#4b4d44,color:#fff,stroke:#a6aa91;
    class G start;
    class A,B forest;
    class AF,BF fork;
    class D optional;
    linkStyle 5 stroke:#d6ae63,stroke-width:3px,stroke-dasharray:6 4;
```

**Read order:** Spawn at Kōsen Gate → choose Forest A or Forest B → each trail leads to its own fork → Forest A's fork has a dead-end branch → the **potential shortcut connects Forest A's fork directly to Forest B's fork**. It does **not** connect back to the gate.

### MVP design notes
- One contiguous forest biome, two playable routes; branching exploration and backtracking.
- Basic bandit, heavy bandit, and one boss. Enemy placements and boss location remain TBD.
- Gold dashed line denotes a **proposed shortcut**, not a mandatory starting connection; its unlock condition is TBD.
- Forest C and the neighboring village gate are excluded from the MVP.
- This diagram is a **topology**, not a geographically scaled level map. Exact trail geometry and distances are TBD.

## Future revisions
Add checkpoint positions, encounters, landmark names, rewards, boss arena, and unlock conditions as they are decided. Keep this diagram simple enough to read on mobile.
