# Architecture Notes

## Content model

The project uses custom Godot `Resource` classes for durable content:

- `WeaponDefinition`
- `EquipmentDefinition`
- `EnemyDefinition`
- `ClassDefinition`
- `LootTable`
- `EnhancementCurve`
- `RoomEventDefinition`

Definitions should stay mostly immutable during a run. Runtime state such as current health, armor durability, enhancement level, inventory contents, and room progress belongs to nodes or future save/run-state objects.

## System boundaries

- `DungeonRun` owns room pacing, floor count, and enemy spawning.
- `LootService` owns drop rolls and pickup creation.
- `EnhancementService` owns upgrade probabilities and failure outcomes.
- `MetaProgressionService` owns permanent profile currency, talent levels, run settlement rewards, and `user://profile_v1.json` persistence.
- `EventService` owns in-run event cost checks and temporary stat reward application.
- `FeedbackService` owns camera shake, procedural one-shot audio, damage numbers, hit sparks, and death bursts.
- `ArmorComponent` owns armor durability, but `CombatResolver` owns damage math.
- Player and enemy scripts consume combat and data APIs, but should not become rule databases.
- Equipment and forge UI live in separate panel scripts under `scripts/ui/` and talk to the player through explicit loadout/enhancement methods.
- `LanSession` is intentionally separate so single-player code can later be driven by an authority/replication layer without rewriting content definitions.

## Boss model

Bosses extend `EnemyDefinition` with three optional resource links:

- `boss_skill_profile` defines active skills, cooldowns, weights, and phase-two scaling.
- `boss_mechanic_profile` defines phase threshold, invulnerability windows, and reserved mechanic ids such as execute windows, intangibility, shield cores, summons, and environment hazards.
- `boss_loot_table` defines boss-specific chest rewards.

Boss loot is awarded through reward chests, not corpse drops. This keeps room completion, reward pacing, and future co-op synchronization in one path.

## Dungeon flow

Rooms are defined as `RoomDefinition` resources under `resources/dungeon/`. `DungeonRun` consumes a room sequence, applies the current room through `RoomPresenter`, spawns encounters when required, spawns interactable reward chests, and unlocks `ExitPortal` when the room reward flow is complete.

The current vertical slice is intentionally deterministic:

- Combat rooms teach the baseline fight loop.
- Treasure rooms spawn guaranteed reward chests.
- Elite rooms add denser armor pressure and better rewards.
- The forge room spawns a forge station; pressing `E` near it opens the forge UI.
- The event room spawns one event station. Current events use run-only costs and rewards, and the Trial Altar can temporarily lock the exit while it spawns an elite enemy.
- Mini boss and boss rooms use the same template path with different enemy groups.

## Interaction flow

The player owns a small interaction area that scans nodes in the `interactables` group. Interactable scenes expose `can_interact(player)`, `get_prompt_text()`, and `interact(player)`. HUD prompt text is driven by the player's current interactable, so new interactables can be added without custom HUD logic.

Event stations use the same protocol as reward chests, forge stations, and exit portals. `DungeonRun` owns event-room placement and trial enemy/chest pacing, while `EventService` owns whether the player can pay the event cost and how temporary run modifiers are applied.

## Meta progression flow

The game starts in the HUD camp overlay. Starting a run applies permanent talent modifiers to the player and enemy drop chance, then starts the deterministic dungeon sequence. Death and final victory both settle the run once, award permanent profile resources, save the profile, and return the player to camp.

## MVP content target

The first playable slice is scoped to ten rooms:

- Rooms 1 and 2: combat
- Room 7: event
- Rooms 3 and 9: treasure
- Rooms 4 and 8: elite
- Room 5: mini boss
- Room 6: forge
- Room 10: boss

The dungeon generator starts as a room-sequence director. Template rooms and graph generation can be added after the combat, drops, and build loop feel good.
