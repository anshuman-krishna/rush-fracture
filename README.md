## rush-fracture
**break speed. survive chaos.**

a fast-paced fps roguelike built in godot 4.6, with procedural runs, build variety, and co-op/competitive multiplayer.

---

**quick note:** before anything else, i started this project without knowing gd-script. this project is co-developed with claude, which helped me learn godot scripting, structure systems properly, and assist with testing and validation throughout development.

---

## current state — v1.0.0

the game is fully playable and stable.

- complete single-player roguelike loop
- working multiplayer (co-op, race, pvp)
- persistent progression with meta upgrades and unlocks
- settings, onboarding, and clean startup flow
- balanced difficulty and economy

---

## core gameplay loop

1. start a run
2. clear procedurally generated rooms
3. pick upgrades and mutations to shape your build
4. survive fracture events and escalating difficulty
5. defeat the boss
6. earn currency, unlock permanent upgrades, repeat

each run is short but plays differently depending on build choices.

---

## movement and combat

- fast fps movement with dash and air control
- momentum-based feel with speed-rewarding mechanics
- three weapon types:
  - **pulse rifle** — balanced hitscan with burst/ricochet upgrades
  - **scatter cannon** — close range with tight spread/double blast options
  - **beam emitter** — continuous damage with heat management and chain/pierce upgrades
- combo system rewards consecutive kills with speed and damage buffs
- hit feedback: recoil, screen shake, damage vignette, hit markers

---

## build system

### upgrades (26 types)
- weapon-specific: burst fire, armor piercing, ricochet, beam chain, tight spread, double blast
- global: damage, fire rate, speed, dash cooldown, health, kill heal
- special: chain reaction, adrenaline surge, temporal break, explosive dash, null field
- cursed: high reward with meaningful trade-offs

### mutations
- powerful run modifiers with downsides
- examples: glass cannon, momentum shield, fracture echo, neural overload

---

## enemies

seven enemy types with distinct behaviors:

| type | role |
|------|------|
| chaser | fast melee rusher |
| shooter | ranged attacker |
| tank | slow, high damage, high hp |
| dasher | high-speed flanker |
| exploder | suicide bomber |
| sniper | long-range, fragile |
| support | buffs nearby enemies |
| displacer | teleports, disrupts positioning |

scaling based on room difficulty, with elite variants.

---

## bosses

- **fracture titan** — final boss with two phases. ground slams, shockwaves, charge attacks. spawns adds in phase 2.
- **fracture warden** — mid-run mini boss. shield pulses, summons minions, teleport slams in phase 2.

both have telegraphed attacks designed to be readable but punishing.

---

## room system

procedural but structured — 5 to 8 rooms per run:

- combat, swarm, elite, recovery, hazard, gauntlet, elite chamber
- difficulty scales per room with adaptive difficulty tracking
- environmental hazards (spike zones, damage tiles)
- visual palette variety per room

---

## fracture events

temporary chaos modifiers during runs:

- low gravity
- enemy speed boost
- random explosions
- vision distortion
- enemy duplication

---

## multiplayer

fully integrated networking with host/client model:

- **co-op** — shared run, synchronized enemies and progression
- **race** — players progress separately, meet later
- **pvp encounter** — players fight using their builds mid-run

server authority for enemies and damage, interpolation for smooth remote movement.

---

## progression

persistent across runs:

- lifetime stats (kills, combos, times, wins)
- fracture shards currency earned per run
- meta upgrades: damage, speed, health, dash cooldown, shard bonus
- unlockables: weapon variants and starting perks
- settings persist (volume, sensitivity, fullscreen, invert mouse)

---

## controls

| action | key |
|--------|-----|
| move | WASD |
| look | mouse |
| shoot | left click |
| jump | space |
| dash | shift |
| weapons | 1 / 2 / 3 |
| toggle hud | F2 |
| debug overlay | F3 |
| pause/menu | escape |

---

## running the project

1. open `game-client/` in godot 4.6+
2. run the main scene (main_menu.tscn)
3. for multiplayer: one player hosts, others join via ip
4. optional: run `backend/` go server for stats tracking

export presets included for windows and macos.

---

## architecture

- modular systems: combat, rooms, enemies, upgrades, mutations, networking, progression
- strict gdscript typing throughout
- signal-driven communication between systems
- multiplayer-aware from the ground up
- throttled ui updates for performance
- type-safe config loading with corruption resilience

---

## project structure

```
rush-fracture/
  game-client/
    scenes/          # godot scene files
    scripts/         # game manager, debug overlay
    systems/         # all game systems (combat, enemy, player, ui, etc.)
    assets/          # game assets
  backend/           # go server for stats/analytics
  shared/            # shared definitions
  docs/              # documentation
  scripts/           # utility scripts
```

---

## notes

this project started as a learning exercise and grew into a complete, playable game.
it is of course not a commercial product, but it is stable, testable, and designed for extensibility.
the goal was to build something real, learn along the way, and keep it enjoyable to work on.
