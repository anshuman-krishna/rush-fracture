# FEATURES.md — What Rush Fracture Actually Has

Verified against the code, not the README (the README has drifted — corrections are called out inline as **[correction]**). Organized by system. This is a snapshot of implemented behavior, not a quality judgment — see REMAINING.md for gaps and risk.

## Core loop

- Start a run → clear a sequence of 5-8 procedurally-composed rooms → pick an upgrade after most rooms → occasionally pick a mutation → survive random fracture events → fight a boss → earn currency → return to menu, spend currency on permanent meta-upgrades/unlocks, repeat.
- Adaptive difficulty: `DifficultyTracker` scores each room's clear time and damage taken, nudging future room difficulty ±15% (never more) toward a "sweet spot," blended 70/30 with history each room.
- Run identity tags generated post-run from playstyle signals (kill rate, combo peak, cursed-upgrade count, mutation picks, room-clear speed) — e.g. "berserker," "speedrunner," "glass cannon," "risk taker," "boss slayer."

## Movement & combat

- Fast FPS movement: acceleration/friction-based, separate air vs. ground handling, jump, dash (0.12s burst, 0.6s cooldown) with camera FOV kick and screen shake on activation.
- Fall-death safety net: falling below y=-10 for 2s kills the player (catches out-of-bounds falls).
- Camera juice: speed-reactive FOV (90→110 based on velocity), screen shake, recoil, dash FOV punch — all in `camera_controller.gd`.
- Hit-feedback ("game feel"): hit-pause (0.03s), kill-freeze slowmo, boss-phase slowmo, with a priority system so boss moments always win over regular combat freezes.
- Three weapons, switchable via 1/2/3:
  - **Pulse rifle** — hitscan, 25 base damage, 0.12s fire interval, 100-unit range. Upgradeable to 3-round burst and +40% armor-piercing damage.
  - **Scatter cannon** — 7-pellet spread hitscan, 8 dmg/pellet, 40-unit range, close-range oriented. Upgradeable to tighter spread and a delayed second blast.
  - **Beam emitter** — continuous hitscan with a heat meter (100 heat, overheats and locks out fire until cooled). Upgradeable to chain-to-nearby-enemy and +50% heat capacity.
- Combo system: kill streak within a 3.5s window builds a multiplier (thresholds at 3/6/10/15 kills → x2/x3/x4/x5), granting temporary speed (+8% to +30%) and damage (+5% to +25%) buffs that revert on combo break.
- Breakable walls: some room obstacles can be destroyed by weapon fire (`_handle_hit_with_breakable`).

## Build system

- **26 in-run upgrade types** — matches the README's claim exactly. Categories: global stats (damage, fire rate, max health, dash cooldown, move speed, air friction retention, kill-heal), weapon-specific (burst fire + armor piercing for rifle; tight spread + double blast for scatter; beam chain + heat capacity for beam), high-impact specials (chain reaction explosions, adrenaline surge, temporal break slowmo-on-kill, ricochet rounds, piercing beam, explosive dash, enemy-slow aura), and 3 cursed upgrades (power surge, fragile speed, berserker pact — each trades a real downside for a bigger payoff). Picked via random 3-of-pool offers after most rooms.
- **8 mutation types** (not stated as a count in the README, but the README's own example list names "neural overload," which **[correction] does not exist in the code** — the 8 are glass cannon, overclock, blood pact, unstable core, velocity addict, temporal distortion, momentum shield, fracture echo). Mutations are offered less often than upgrades and always carry an explicit upside/downside pair.

## Enemies

- 8 distinct archetypes, each a separate controller with its own behavior: chaser (melee rush), shooter (ranged, LOS-gated), tank (slow/high-HP/high-damage), dasher (flanking burst-speed melee), exploder (suicide-detonate), sniper (long-range telegraphed shot, interruptible by taking damage mid-telegraph), support (buffs/heals nearby enemies periodically), displacer (teleports to reposition/disrupt).
- Elite variants: stat multipliers (health x2.5, +30% speed, x2 damage, 1.5x scale) plus type-specific special behaviors (burst-fire, ground-slam, faster buffs, chain-dash) for 6 of the 8 types — chaser and exploder have no elite-specific behavior, just bigger numbers.
- Spawn composition is a weighted random table gated by both room type and a difficulty threshold, not a fixed list per room.
- No pathfinding (no NavigationAgent3D anywhere) — all chase/approach behavior is straight-line vectors relying on `move_and_slide()` to slide around obstacles.

## Bosses

- **Fracture Titan** — two-phase final boss. Ground slams, shockwaves, charge attacks, spawns adds in phase 2. Distance-threshold + random attack selection with clearly telegraphed (color-emission, 0.4-0.8s wind-up) attacks.
- **Fracture Warden** — mid-run miniboss. Shield pulses, minion summons, teleport slams in phase 2.
- Both use a real state machine (`IDLE → TELEGRAPH → ATTACKING → COOLDOWN`) — the only enemies in the game that do.

## Room system

- 9 room types: combat, swarm, elite, recovery, transition, boss, hazard, gauntlet, elite chamber (`room_definitions.gd`), 6 visual palettes.
- **[correction]** Rooms are not distinct floor plans — every room is the same persistent circular arena (35-unit radius), procedurally re-populated with obstacles (pillars, crates, ramps, breakable walls — ~9 obstacle archetypes) drawn from a room-type-specific weight table. Boss/gauntlet/elite-chamber rooms get hand-authored deterministic layouts instead of randomized ones.
- Runs are 5-8 rooms (`RoomGenerator`), always combat-first and boss-last. Race mode uses a fixed 4-room leg (`RaceGenerator`).
- Deterministic per-room seeding (`seed(room.id.hash())`) supports reproducible layouts, notably for multiplayer sync.

## Fracture events

- 7 timed chaos modifiers, rolled per room entry (10% base chance + 8% per difficulty point, skipped during boss fights): velocity surge, unstable gravity (weakened), enemy duplication on kill, void drift (near-zero gravity), adrenaline leak (2x enemy speed — has a known revert bug, see REMAINING.md), random explosions, and vision distortion (`fracture_definitions.gd`).
- Correction to an earlier pass of this doc: "enemy duplication" is *not* dead. `fracture_manager.gd`'s `_apply_effect`/`_revert_effect` have empty case blocks for `ENEMY_DUPLICATION` (it needs no per-frame state), but the actual effect lives in `game_manager.gd:384-387` (`_on_room_enemy_killed`) — while the fracture is active, each kill has a 30% chance to call `room_controller.spawn_duplicate_enemy()`. Confirmed working as designed.

## Multiplayer

- ENet transport via Godot's high-level multiplayer API, listen-server model (host is also a player), up to 4 players.
- Room-code join UX (6-character code, Among Us-style) that derives a network port deterministically from the code.
- The join flow now has a real IP-entry field alongside the room-code field (blank defaults to `127.0.0.1` for same-machine testing). Hosting surfaces the host's best-guess LAN IPv4 in the status label. Fixed 2026-08-27 — see REMAINING.md's changelog note. Still no NAT traversal/relay, so WAN play needs manual port-forwarding by the host.
- Three modes: **co-op** (shared run, synced enemies/progression), **race** (separate progress, converge after 4 rooms into a PvP encounter), **pvp encounter** (200hp separate pool, 0.3x damage scaling, last-player-standing).
- Host-authoritative enemy simulation, `MultiplayerSynchronizer`-based position/rotation/health sync for players, client-side optimistic damage prediction reconciled against host for PvE.
- Ping measurement exists (unreliable RPC ping/pong) but isn't surfaced in any UI.
- 21 RPC/authority call sites spread across 16 files — multiplayer-awareness is genuinely threaded through combat, enemies, and health, not bolted on as an afterthought.

## Progression

- Persistent across runs: lifetime stats, `fracture_shards` currency earned per run, 10 meta-upgrade types (damage/speed/health/dash-cooldown/shard-bonus and more, each with per-level cost scaling), 14 unlockables (weapon variants, starting perks, cosmetics) gated by simple requirement checks.
- Settings persist independently: master volume, mouse sensitivity, invert-Y, fullscreen.
- Onboarding overlay shown once (dismiss-on-any-input), tracked via a persisted flag.

## UI/UX

- Main menu, pause menu, settings menu, progression/upgrades screen, run summary screen, room-announce banner, run HUD, upgrade-selection screen, mutation-selection screen — all hand-built at runtime (not static `.tscn` layouts for the cards), visually consistent color language (orange/red = damage, cyan = beam/info, purple = cursed).
- Debug overlay (F3 toggle) showing room/difficulty/network/boss-HP internals — present in every build, not gated to dev builds.

## Audio

- 17 distinct sound cues (weapon fire, hits, boss events, UI clicks) routed through a single 12-voice pooled player.
- **[correction]** No actual sound files exist — every cue is a synthesized sine/noise placeholder tone generated at runtime. There is one audio bus (Master) — no separate music/SFX mixing.

## Backend (Go, optional, not wired to the client)

- REST API: user creation/lookup, run start/end/lookup, room-event logging, upgrade logging, stats lookup, health check, plus a websocket endpoint.
- SQLite storage, clean parameterized-query layering (controllers → services → repositories).
- **[correction, fixed 2026-08-27]** The `GET /api/stats/{userId}` endpoint used to always 404 (nothing ever wrote to a separate `stats` table). That table was removed and stats are now computed live as a SQL aggregate over `runs`, so the endpoint works. Also hardened since the original write-up: shared-secret API key auth, CORS allow-list, per-IP rate limiting, request body size caps, per-field bounds validation on gameplay data, and websocket origin checks — see REMAINING.md §3 for exact status of each. The websocket hub's broadcast channel is still dead code — no real-time relay is functional. **The Godot client still contains no code that calls this backend at all** — despite the README describing it as "optional: run `backend/` go server for stats tracking," there is currently no stats tracking happening even if you run it.

## Platforms

- Godot export presets exist for **Windows and macOS only** — no Linux preset, despite Godot supporting it natively.
