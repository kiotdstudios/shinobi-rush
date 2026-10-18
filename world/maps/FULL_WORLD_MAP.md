# Kōsen Forest — Full World Expansion Map

**Status:** Long-term concept · The MVP-only diagram is at [MVP_WORLD_MAP.md](MVP_WORLD_MAP.md).

```mermaid
flowchart TB
    G["KŌSEN VILLAGE GATE<br/>Player start"]
    G --> A["FOREST A"]
    G --> B["FOREST B"]
    G -.-> C["FOREST C<br/>Future — layout TBD"]
    A --> AF{"A FORK"}
    B --> BF{"B FORK"}
    AF --> D["Dead-end clearing"]
    AF <-.->|"Potential shortcut"| BF
    BF -.-> N["NEIGHBORING VILLAGE GATE<br/>Future expansion"]

    classDef start fill:#30473d,color:#fff,stroke:#89b99a,stroke-width:2px;
    classDef mvp fill:#243b32,color:#fff,stroke:#7dab8c;
    classDef future fill:#41474b,color:#fff,stroke:#a7aeb2,stroke-dasharray:5 4;
    class G start;
    class A,B,AF,BF,D mvp;
    class C,N future;
    linkStyle 6 stroke:#d6ae63,stroke-width:3px,stroke-dasharray:6 4;
```

### Confirmed topology
- Three forest routes ultimately lead away from Kōsen Gate.
- Forest A forks; one branch terminates in a dead end.
- Forest B forks; one branch leads toward the neighboring village gate in the future.
- **Potential shortcut: Forest A fork ↔ Forest B fork. Never route this shortcut to the Kōsen Gate.**
- Forest C's downstream path is still unspecified.
- The neighboring village gate and Forest C are **not** part of the MVP.
- Diagrams represent route connections, not physical scale.

### Revisions
- v0.2: Corrected shortcut to join the two forks; separated full-world and MVP diagrams.
