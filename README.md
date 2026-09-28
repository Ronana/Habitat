# Habitat

**A 3D creature-garden sim built in Godot 4, inspired by *Viva Piñata* and reimagined in my own design.**

<!-- TODO: add a screenshot or GIF, e.g. docs/screenshot.png -->

Shape a wild garden, grow plants and build features, and attract a cast of forest creatures. Each species has its own conditions for visiting, moving in and bonding. Meet those conditions and the garden grows into a living ecosystem, where each new resident opens the way for the next.

> 🚧 **Early development (v0.0.1).** Solo project, actively being built.

## Gameplay systems

- **Attraction and residency:** species progress *Appears → Visits → Resident → Bonded* based on what's in your garden, evaluated live by an `AttractionManager`.
- **Creature AI ("roamers"):** a shared state machine (wander, idle, flee, sleep, sleep-walk, agitated) with needs and happiness.
- **Breeding and eggs:** bonded pairs use shelters to breed, and eggs hatch into new residents.
- **Creatures:** Glowfox, Mossdeer, Thornmouse, Crystalback, Stoneback, Emberowl and more, each with its own den or habitat scene.
- **NPC visitors:** characters such as Doc Birtle, Gus, Torvald and Maren, each with their own behaviours.
- **Living world:** day/night cycle, seasons, weather, ground fog and plant growth.
- **Garden building:** tool wheel and shovel, placeable plants and decorations (berry bushes, lanterns, fountains, fences, totems…) with item health.
- **Progression:** currency, inventory, garden prestige score, milestones, objectives and a tutorial.
- **Field journal:** tracks what each species needs to visit and to move in.
- **Save/load system**, settings menu and an in-game dev console.

## Tech

| Area | Tools |
|---|---|
| Engine | Godot 4.6 (Forward+), GDScript |
| Terrain | [Terrain3D](https://github.com/TokisanGames/Terrain3D) with a custom splat-map manager |
| Environment | [ProtonScatter](https://github.com/HungryProton/scatter) for foliage, [Waterways](https://github.com/Arnklit/Waterways) for water |
| Camera | [Phantom Camera](https://github.com/ramokz/phantom-camera) |
| 3D modelling | Blender (custom Glowfox model, props) |
| Large files | Git LFS for scene files |

## Project structure

```
habitat/
  project.godot
  scripts/                    game code: managers, creatures, NPCs, tools, UI
  scenes/                     main menu, garden, creature dens, props
  assets/                     models, textures, foliage, cliffs
  addons/                     third-party Godot plugins
  HABITAT_FEATURE_ROADMAP.md  design research and planned features
```

## Running it

1. Install [Godot 4.6](https://godotengine.org/download) and [Git LFS](https://git-lfs.com).
2. Clone with LFS so the scene files download:
   ```bash
   git lfs install
   git clone https://github.com/Ronana/Habitat.git
   ```
3. In Godot: **Import → `habitat/project.godot` → Run** (F5).

## Roadmap

See [`habitat/HABITAT_FEATURE_ROADMAP.md`](habitat/HABITAT_FEATURE_ROADMAP.md). Next up: seed-planting and egg-hatch animations, breeding indicators, and more "game feel" polish.

## Credits

- Environment textures and models from [Poly Haven](https://polyhaven.com)
- Character models from [KayKit](https://kaylousberg.itch.io) and [Quaternius](https://quaternius.com)
- Godot plugins listed under **Tech** above

*Habitat is an independent fan-inspired project. It is not affiliated with Rare, Microsoft or the Viva Piñata franchise, and uses no assets from it.*
