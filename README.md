# Forgebound Depths

Original Godot 4.x top-down action roguelite dungeon looter prototype.

## Current vertical slice

- One playable class: Vanguard
- Eight starter/drop weapons
- Fourteen equipment definitions
- Three normal enemies
- One mini boss and one boss
- Seeded ten-floor run director
- Data-driven loot, armor, and enhancement foundations
- LAN-ready session wrapper using Godot ENet for a later co-op pass
- Boss-specific loot tables, skill profiles, and mechanic profiles
- Main menu camp with permanent meta progression and JSON profile saving
- In-run event room with shrine and trial interactables
- Interactable pickups with weapon/equipment comparison preview
- Original 32px pixel placeholder art for core actors, interactables, projectiles, and the dungeon floor
- Void arcana build drops with echo and gravity weapon affixes
- Equipment UI v2 with filtering, sorting, slot inspection, and explicit forge handoff
- Manual or automatic run seeds for repeatable room/event/drop paths

## Architecture goals

- Content is defined mostly as Godot `Resource` files under `resources/`.
- Runtime systems live under `scripts/systems/`.
- Combat rules live under `scripts/combat/`.
- Entity scripts stay thin and read definitions instead of hardcoding stats.
- Placeholder pixel art lives under `assets/sprites/` and can be regenerated from `tools/generate_pixel_art.gd`.
- Multiplayer-facing logic is isolated in `multiplayer/` for future LAN co-op.

## Run

Open this folder with Godot 4.x and run the main scene.

Controls:

- Move: WASD or arrow keys
- Aim: mouse
- Fire: left mouse button
- Interact: E
- Pick up loot: press `E` near a drop after checking the comparison panel
- Equipment panel: `Equipment` button, with filters, sorting, equipment slots, and comparison details
- Forge panel: interact with the forge station, or use the unlocked `Forge` button while in a forge room
- Exit room: press `E` at the portal after the room is clear
- Run seed: leave the camp seed field blank for a random seed, or enter an integer to replay the room/event/drop path

## Meta progression

Runs now award permanent profile resources after death or completion:

- Gold
- Souls
- Talent Points

The camp menu includes four permanent talents:

- Vital Core
- Reinforced Plating
- Weapon Training
- Scavenger Instinct

Profile data is saved to `user://profile_v1.json`.

## Current room pacing

The MVP run generates ten data-driven rooms from the active seed:

1. Combat
2-4. One each: Combat, Treasure, Elite
5. Mini boss
6-9. One each: Forge, Event, Elite, Treasure
10. Boss

Bosses now use dedicated loot tables and skill/mechanic profiles. Current examples:

- Cinder Bulwark: charge, molten guard, shard burst
- Depths Warden: void lance, gravity ring, rift fan

The event room uses run-only risk/reward choices:

- Ember Pact trades current health for run-long damage.
- Iron Oath spends armor durability for armor and armor pierce.
- Trial Altar locks the exit, spawns an elite Iron Husk, then opens a bonus chest.
- Starless Lens trades current health for critical void pressure.
- Rift Anchor spends armor durability for damage and armor pierce at a movement cost.
