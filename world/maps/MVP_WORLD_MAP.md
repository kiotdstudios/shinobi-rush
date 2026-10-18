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
    AF <-->|"Confirmed connecting path"| BF

    classDef start fill:#30473d,color:#fff,stroke:#89b99a,stroke-width:2px;
    classDef forest fill:#243b32,color:#fff,stroke:#7dab8c;
    classDef fork fill:#355647,color:#fff,stroke:#9bc7a7;
    classDef optional fill:#4b4d44,color:#fff,stroke:#a6aa91;
    class G start;
    class A,B forest;
    class AF,BF fork;
    class D optional;
    linkStyle 5 stroke:#7dab8c,stroke-width:3px;
```

**Read order:** Spawn at Kōsen Gate → choose Forest A or Forest B → each trail leads to its own fork → Forest A's fork has a dead-end branch → the **confirmed path connects Forest A's fork directly to Forest B's fork**. It does **not** connect back to the gate.

### Locked exploration rule
- **Both Forest A and Forest B are open immediately** when the player leaves Kōsen Village Gate; no quest gate or artificial lock.
- **Forest A is the lower-difficulty route**, introducing basic bandits, combat practice, and exploration.
- **Forest B is the higher-difficulty route**, including tougher encounters and heavy bandits. Players may enter it first at their own risk.
- The **Forest A fork ↔ Forest B fork** connection is a real traversable path, allowing travel between both forests without returning to the gate.
- Exact enemy placements, rewards, and boss location remain TBD.

### MVP design notes
- One contiguous forest biome, two playable routes; branching exploration and backtracking.
- Basic bandit, heavy bandit, and one boss. Enemy placements and boss location remain TBD.
- **Confirmed traversable path** connects Forest A fork and Forest B fork. No unlock condition is assumed.
- Forest C and the neighboring village gate are excluded from the MVP.
- This diagram is a **topology**, not a geographically scaled level map. Exact trail geometry and distances are TBD.

## Future revisions
Add checkpoint positions, encounters, landmark names, rewards, boss arena, and unlock conditions as they are decided. Keep this diagram simple enough to read on mobile.


## Progression discovery and route tutorials — design direction
- **Jutsu scrolls** are discoverable throughout the world. Collecting a scroll adds **unlearned knowledge** to inventory; it does not instantly unlock a technique.
- Players bring the required scrolls and/or crafting materials to a **trainer** at **Training Grounds** (universal gameplay term; village-specific local names and architecture), exchange the resources, and learn the corresponding jutsu.
- Learned techniques can be assigned to the existing four R2 technique slots. Exact costs and learning interaction TBD.
- **Awakenings** are taught by specialist NPCs, not granted by scrolls alone. Training requires a specified number of encounters/challenges and specified crafting items; requirements vary by awakening and remain TBD.
- Eight Gates and Sage Mode are mechanical inspirations; use original terminology, lore, and visual designs in Shinobi Rush.
- **Forest A** introduces scroll/material discovery, inventory, and trainer-based learning; its dead-end branch is a candidate for the first scroll.
- **Forest B** introduces specialist NPCs, awakening prerequisites, and crafting materials.
- **Both forests stay open immediately.** Route tutorials are contextual and optional; entering Forest B first must not break onboarding or progression.
- **Locked naming:** Training Grounds is the universal term. **Kōsen Village uses Mastery Chambers** as its local training-ground identity. **Inner Mastery Court** is a proposed name for another village's training grounds (village assignment TBD). Each village can have distinctive architecture while sharing the same scroll-learning function.


## Trainer-based jutsu learning — current locked design
- **No jutsu-learning minigames or puzzles.** This supersedes the earlier Mastery Chamber minigame concept.
- Every learnable jutsu requires **both technique-specific scroll fragments AND crafting materials**. Neither resource alone is sufficient.
- Visit a **trainer** at a Training Ground (Kōsen's local training facility: **Mastery Chambers**) and exchange the required scroll fragments and crafting materials to learn the technique.
- Learned jutsu enters the usable skill inventory and can be assigned to the four R2 technique slots.
- **Awakenings remain distinct:** NPC specialists teach them after required encounters/training milestones and crafting-item prerequisites.
- **MVP:** one trainer, one obtainable jutsu, resource requirement, exchange interaction, and learned-skill equip flow.
- Exact fragment counts, material types, costs, drop locations, and exchange quantities are TBD; exchanges consume the required resources.

## Locked jutsu resource rule
- Jutsu learning requires **scroll fragments + crafting materials together** at a trainer in the village-specific Training Grounds (Kōsen: Mastery Chambers).
- Fragments are **technique-specific**, with requirements and crafting materials varying by jutsu.
- Once the trainer exchange is completed, the jutsu is learned and can be equipped.
- Sample costs mentioned during planning are illustrative only and are **not locked balance values**.


## Resource acquisition and trade — locked direction
Every learnable jutsu requires **technique-specific scroll fragments plus crafting materials**, exchanged at a trainer in the Training Grounds (Kōsen: Mastery Chambers).

**Approved resource sources:**
1. Enemy loot drops (including bandits, elites, bosses).
2. Hidden chests and exploration discoveries.
3. Quest rewards.
4. Random in-world loot drops.
5. Player-to-player trading of eligible resources.
6. Village markets and NPC merchants.
7. Traveling specialist NPC merchants with distinctive inventories.

**Implementation scope:** For the single-player MVP, prioritize enemy drops, chests, quest rewards, random world loot, and a basic NPC merchant. Player trading and a broader market economy are future systems; do not imply that multiplayer trading ships in the MVP. Exact drop rates, loot tables, item tradability, market prices, merchant rotations, and rarity balance remain TBD.

**Forest onboarding:** Introduce multiple acquisition sources through contextual discoveries on Forest A and Forest B without forcing a linear tutorial or closing either path.


## Supply bag capacity and upgrades — locked initial rules
- The player starts with **12 total shared inventory slots** for scroll fragments and crafting materials combined (not 12 each).
- Increasing bag capacity requires gathering **bag-upgrade materials** and performing an upgrade. Upgrade service/location and material recipes TBD.
- Inventory capacity is a meaningful exploration and resource-management constraint.
- **Locked stacking:** identical scroll fragments and crafting materials stack up to **99 units per slot**. The 100th unit begins a new stack and consumes another shared bag slot.
- **Locked jutsu fragment costs:** basic jutsu require **10 technique-specific scroll fragments**; rarer jutsu require **20 or more** fragments, scaled by rarity. Every jutsu additionally requires crafting materials and trainer exchange.
- **Not yet locked:** exact expansion increments and maximum bag capacity; whether quest items use separate slots; specific rare-tier costs and material recipes.
- **Suggested only (not locked):** 12 → 16 → 20 → 24 slots; identical items stack up to 99 units per slot.

## Inventory stacking and jutsu fragment thresholds — confirmed
- Shared bag begins at **12 slots** for fragments and materials.
- Each identical item stack holds **99**; additional units split into new stacks and consume additional slots.
- **Basic jutsu: 10 fragments** of that specific technique, plus crafting materials, exchanged at a trainer.
- **Rare jutsu: 20+ fragments** of that specific technique, plus crafting materials, exchanged at a trainer. Precise higher-tier costs TBD.

## Full inventory and loot pickup — confirmed
- If all 12 shared slots (or the current upgraded capacity) are occupied, the player **cannot pick up loot that requires a new slot**.
- Show **Inventory Full** feedback and require the player to manually drop an item or stack to free space before collecting the loot.
- Dropped items remain in the world and can be picked up again; uncollected loot remains at its source. Dropped loot persists until the player loads a save or transitions to another map; returning to the previous map does not restore it.
- If a matching existing stack has room (up to 99), items may be added without needing a new slot; overflow requiring a new stack is blocked while full.
- No automatic sending to storage or automatic deletion to make room.

## Seamless forest streaming and dropped-loot lifetime — confirmed
- Forest paths within the same world map connect **seamlessly without loading-screen transitions**. Moving between Forest A and Forest B does **not** clear dropped items; the same applies to Forest C when built.
- Dropped items persist at their world positions while the player remains within the **same loaded map**, even after traveling to another forest path and returning.
- **On a new-map transition** (for example, entering a neighboring village), all dropped loot from the previous map is cleared. Returning to that map does not restore those drops.
- **Loading a saved game** also clears temporary dropped loot; it is not persistent save data.
- Loot the player has not picked up remains available within the active map. Treatment of unopened chests, quest-critical items, and enemy respawns is separate and TBD.
- **Implementation direction:** keep the authored forest route graph, forks, and connections fixed; stream chunks/props/encounters procedurally as needed for fluid travel. This does **not** mean randomizing the established map topology.
- MVP still contains Kōsen Gate and Forest A/B; Forest C and neighboring village transitions can be added later.


## Enemy respawn lifecycle — locked
- **Regular enemies respawn on a fresh map load**, following the same boundary concept as temporary dropped loot.
- Moving seamlessly among forest paths in the **same map** does **not** respawn defeated enemies, even if their chunks are streamed out and back in.
- When the player transitions to a **different map** (e.g., another village), regular-enemy defeat state for the departed forest map is reset. Returning to the forest repopulates normal encounters at their designated spawn locations.
- **Loading a saved game** repopulates regular enemies.
- Bosses, unique enemies, and quest-critical encounters should **not automatically respawn** under these rules; track their persistent completion states separately unless explicitly designed as repeatable encounters.
- Keep regular-enemy defeat state in temporary active-map data independent of streamed chunk visibility.

## Save Stones and death respawn — confirmed
- On death, the player respawns at the **nearest activated Save Stone**.
- Save Stones are checkpoint landmarks, distinct from the trainer-based Mastery Chambers.
- Proposed checkpoint placements (not locked): Kōsen Village Gate, Forest A, and Forest B.
- **Still to decide:** whether proximity is measured by map distance or travel distance; what happens if no nearby stone has been activated; health/resource restoration; whether inventory or currency is lost on death; whether dying resets dropped loot. These are not yet locked.

## Death-triggered enemy respawn — confirmed
- **Player death resets all regular enemies in the active forest map**, repopulating their designated spawn locations when the player respawns at the nearest activated Save Stone.
- This reset occurs even without a map transition or manual save load, overriding the ordinary same-map no-respawn rule specifically for death.
- **Bosses and completed story objectives remain completed**; unique/quest-critical encounters are not automatically reset.
- **Learned jutsu and persistent player progression are retained** on death.
- **Death clears all temporary dropped loot** in the active map, just like transitioning to a different map or loading a save.

## Death cleanup of dropped loot — confirmed
- On **player death**, all player-dropped items left on the ground in the active map **disappear permanently** and cannot be recovered.
- Items held in inventory are **not** deleted by this rule.
- Temporary dropped loot also clears on **loading a saved game** or **transitioning to a different map**.
- Seamless forest-path travel alone does **not** clear dropped loot.


## Approved save, healing, loot, and fast-travel rules — locked
- Save Stones must be **activated by player interaction**; activated stones allow manual saving and act as eligible death respawn points. Respawn uses the nearest activated stone.
- Death respawn restores **100% HP and Chakra**.
- **Autosave when entering a new map**; manual saving at activated Save Stones.
- **Consumable healing items** are used during exploration and occupy the shared inventory capacity.
- **Uncollected enemy loot is cleared on player death**, along with manually dropped items. This does not delete items already collected into inventory.
- **Fast travel** becomes available later in progression, and only between previously activated Save Stones. Unlock conditions TBD.

## Traditional RPG leveling and layered stats — locked
- Players earn **XP** through combat, quests, exploration milestones, and training challenges; leveling raises base stats and awards allocatable attribute points.
- Core attributes: **Health** (max HP), **Chakra** (max jutsu resource), **Strength** (physical damage/heavy attacks/launchers), **Defense** (damage mitigation), **Speed** (movement/attack speed/dodge performance).
- Effective combat strength is influenced by **base level/stats + attribute allocation + equipment + training + jutsu + consumable items + awakening effects + active buffs/debuffs**.
- Buffs may be temporary or permanent where appropriate (e.g., training increases). Equipment may grant passive bonuses; consumables, jutsu, and awakenings may provide timed combat bonuses.
- Debuffs can include **poison, burns, slows, defense reduction, chakra disruption, and Strength reduction**; effects can expire or be countered through items or abilities.
- Display modified stats and active effects clearly in character UI, distinguishing base values from positive/negative modifiers.
- Exact XP curves, numerical bonuses, stacking rules, effect durations, and balancing are **TBD**, not approved as final values.
