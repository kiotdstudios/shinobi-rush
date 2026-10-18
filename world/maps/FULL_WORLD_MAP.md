# Kōsen Forest — Full World Expansion Map

**Status:** Long-term concept · The MVP-only diagram is at [MVP_WORLD_MAP.md](MVP_WORLD_MAP.md).

```mermaid
flowchart TB
    G["KŌSEN VILLAGE GATE<br/>Player start"]
    G --> A["FOREST A"]
    G --> B["FOREST B"]
    G -.-> C["FOREST C<br/>Future expansion"]
    A --> AF{"A FORK"}
    B --> BF{"B FORK"}
    AF --> D["Dead-end clearing"]
    AF <-.->|"Potential shortcut"| BF
    BF -.-> N["NEIGHBORING VILLAGE GATE<br/>Future expansion"]
    C -.-> CF{"FOREST C — THREE-WAY FORK"}
    CF -.-> C1["Path 1<br/>Future destination TBD"]
    CF -.-> C2["Path 2<br/>Future destination TBD"]
    CF -.-> N

    classDef start fill:#30473d,color:#fff,stroke:#89b99a,stroke-width:2px;
    classDef mvp fill:#243b32,color:#fff,stroke:#7dab8c;
    classDef future fill:#41474b,color:#fff,stroke:#a7aeb2,stroke-dasharray:5 4;
    class G start;
    class A,B,AF,BF,D mvp;
    class C,CF,C1,C2,N future;
    linkStyle 6 stroke:#d6ae63,stroke-width:3px,stroke-dasharray:6 4;
```

### Confirmed topology
- Three forest routes ultimately lead away from Kōsen Gate.
- Forest A forks; one branch terminates in a dead end.
- Forest B forks; one branch leads toward the neighboring village gate in the future.
- **Potential shortcut: Forest A fork ↔ Forest B fork. Never route this shortcut to the Kōsen Gate.**
- Forest C splits into **three paths**: one connects to the neighboring village gate; the other two have destinations to be decided.
- Forest B's previously planned connection to the neighboring village gate remains shown; both routes can approach that gate unless revised later.
- The neighboring village gate and Forest C are **not** part of the MVP.
- Diagrams represent route connections, not physical scale.

### Revisions
- v0.3: Added Forest C three-way fork with one route to the neighboring village gate and two future destinations.
- v0.2: Corrected shortcut to join the two forks; separated full-world and MVP diagrams.
