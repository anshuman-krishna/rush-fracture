# REMAINING.md — What's Left to Deploy & Publish Rush Fracture

This is written for a **commercial public release**, not "good enough to keep hacking on." It intentionally does not try to preserve the current design — where something needs to be rebuilt to ship a real product, it says so. Items are grouped by category, roughly ordered by severity within each group. "Critical" means the game is broken or unsafe without it; "major" means a real release shouldn't ship without it; "minor" is polish/nice-to-have.

---

## 1. Critical bugs

**Status: fixed in the 2026-08-27 rebuild pass** (see `git log`). Kept here as a record of what was wrong and how it was addressed, since the original write-up is still useful context for reviewing the fix.

- ~~**Multiplayer join is broken for anyone not on the host's machine.**~~ **Fixed.** `main_menu.tscn` now has an `IpInput` field next to the room-code field (blank = same device, matching the old behavior); `_on_join()` passes it through to `network_manager.join_by_code(code, address)`. Hosting now also surfaces the host's best-guess LAN IPv4 (`main_menu.gd:_get_local_lan_ip`) in the status label so there's something real to share alongside the code. This does **not** add NAT traversal/relay (see §6) — it only fixes the "the UI never even asks for an address" bug, so LAN play now actually works and WAN play works if the host manually port-forwards.
- ~~**PvP damage doesn't propagate over the network.**~~ **Fixed, and hardened.** `PvPManager.try_pvp_damage()` (`pvp_manager.gd`) is now host-authoritative: a non-host peer sends `_rpc_request_pvp_damage` to the host (peer 1) instead of mutating shared state locally; the host validates, applies, and rebroadcasts the authoritative result via `_rpc_pvp_damage` to every peer. This closes both the desync bug and the "any peer can forge arbitrary PvP damage" hole in one change. The now-redundant `_rpc_pvp_elimination`/`_rpc_match_over` RPCs (dead code, superseded by the fact that `_apply_pvp_damage` already runs identically everywhere) were removed.
- ~~**Unvalidated damage RPC is a one-shot cheat vector.**~~ **Mitigated, not fully solved.** `HealthComponent._rpc_take_damage()` now clamps incoming damage to `MAX_DAMAGE_PER_HIT` (250) and rate-limits to one accepted hit per 40ms per component. This kills the trivial "one-shot any enemy/boss" and "spam unlimited damage" versions of the exploit. It does **not** validate that the claimed damage matches the attacker's actual weapon/upgrade state — doing that properly means the host tracking each attacker's live loadout and would be a larger change; worth doing before any competitive/leaderboard feature depends on this being uncheatable.
- ~~**Fracture "double speed enemies" revert bug.**~~ **Fixed.** `FractureManager` now tracks exactly which enemies it buffed (`_speed_buffed_enemies`) and only those get the 0.5x revert — an enemy spawned mid-fracture (gauntlet wave, duplication proc) is left alone instead of getting incorrectly halved.
- ~~**Kill-explosion (chain reaction upgrade) aims from the camera, not the kill.**~~ **Fixed.** The kill position now flows through the signal chain instead of being re-derived from camera aim: `BaseWeapon.enemy_killed`/`WeaponManager.enemy_killed` now carry a `Vector3`, and `game_manager._spawn_kill_explosion(origin)` centers the explosion on the enemy that actually died.
- ~~**Debug overlay ships in every build.**~~ **Fixed.** `debug_overlay.gd` now checks `OS.is_debug_build()` before responding to F3 at all, so it's inert in release exports regardless of `export_presets.cfg`'s (still empty) exclude filter.
- ~~**`ELITE_CHAMBER` rooms never actually spawn elites.**~~ **Fixed.** `RoomController._spawn_enemies()` now marks *every* enemy elite in an `ELITE_CHAMBER` room (vs. just enemy index 0 in a regular `ELITE` room) — matches the room's own name and its harder `enemy_composition.gd` weight table.
- ~~**Stray debug `print()` calls ship to release console/log.**~~ **Fixed.** Pure-noise prints (`"main menu ready"`, `"game manager ready"`, etc.) were removed outright; the genuinely useful connection-diagnostic prints in `network_manager.gd` were kept but gated behind a new `_debug_log()` helper that no-ops outside `OS.is_debug_build()`.
- **Corrected, not a bug**: an earlier pass of this document claimed the `ENEMY_DUPLICATION` fracture was a dead stub. It isn't — the actual effect lives in `game_manager.gd:_on_room_enemy_killed` (30% chance to duplicate an enemy per kill while the fracture is active), not in `fracture_manager.gd` where the original check looked. Verified working as designed; no change made.
- **Also cleaned up while in these files**: a fully commented-out duplicate `_input()` block in `player_controller.gd` was removed; two non-English leftover comments (one in `enemy_controller.gd`, one in `beam_emitter.gd`) were translated.

---

## 2. Art, audio, and presentation — the single biggest gap

This is not a polish item, it's foundational: **the project currently has zero external assets of any kind.** `game-client/assets/` does not exist, and a repo-wide search for `.png/.jpg/.svg/.wav/.ogg/.mp3/.ttf/.otf/.glb/.gltf` returns nothing outside the `.git` history. Every weapon, enemy, room prop, and effect is a procedurally-assembled primitive mesh (boxes, cylinders, spheres) built in GDScript at runtime, using the default Godot UI font and no game icon.

- **Visuals**: needs either (a) a real art pass — modeled/textured weapons, enemies, environment art, UI skin, particle/VFX assets, or (b) a deliberate decision to keep the current procedural-primitive aesthetic and *polish it intentionally* (better materials, lighting, post-processing, a coherent minimalist art direction) rather than leave it as unstyled programmer art. Either path is a substantial scope of work; right now there is no art direction decision made at all.
- **Audio**: all 17 sound cues (weapon fire, hits, boss events, UI) are synthesized placeholder sine/noise tones generated in `audio_manager.gd:_fill_placeholders()`. None of this is shippable as-is — needs real SFX, a music score/loop system (there's currently no music at all, and only one audio bus, so no music/SFX separation exists to mix into even once music is added).
- **No game icon** — `project.godot` has no `application/config/icon` set, and export presets have empty `application/icon` fields for both Windows and macOS. Will ship with the default Godot icon.
- **No UI font** — default Godot theme font throughout every menu and HUD element.
- **No marketing assets at all**: no store capsule/header art, no screenshots, no trailer, no key art, no logo. Every storefront (Steam, itch.io, console cert) requires these before a listing can even be created, let alone approved.

---

## 3. Backend security & production readiness

The Go backend is well-structured (clean layering, parameterized SQL, no injection issues) but is a prototype, not something safe to expose to the public internet, and — separately — the client doesn't even call it right now.

- ~~**No authentication anywhere.**~~ **Partially fixed.** Added `APIKeyAuth` middleware — a shared-secret `X-API-Key` header check (set via `API_KEY` env var) gating every route except `/health`. This is **not per-user auth** (there's still no login/session system, so it can't stop one user from posting stats against another user's ID) — it just closes the "wide open to the entire internet" gap. Real per-user auth is still a real design decision to make before any leaderboard/anti-cheat feature depends on this.
- **No input validation on gameplay data** — still open. Score, level, kills, duration, combo, mutations, tags are persisted verbatim from client JSON with no bounds/type checks. Not touched in this pass.
- ~~**No rate limiting, no request body size limits.**~~ **Rate limiting fixed** — stdlib-only per-IP fixed-window limiter (`middleware.RateLimiter`, default 120 req/min, configurable via `RATE_LIMIT_PER_MIN`), no external dependency added since there's no Go toolchain in this environment to vet a new module's `go.sum` hashes. **Request body size limits still open** — not addressed.
- ~~**CORS is wide open.**~~ **Fixed.** Replaced the `*` wildcard with an allow-list (`ALLOWED_ORIGINS`, comma-separated) — an origin only gets `Access-Control-Allow-Origin` echoed back if it's on the list; empty (the default) means no browser can call the api cross-origin at all.
- **Websocket accepts any origin** with no auth — still open, still low-impact since the broadcast path is dead code.
- ~~**`GET /api/stats/{userId}` 404s forever.**~~ **Fixed.** Removed the separate `stats` table (nothing ever wrote to it — same "second source of truth that drifts" problem fixed on the client side, see §4). Stats are now computed live as a SQL aggregate over `runs`, so the endpoint always returns a real (possibly zeroed) result instead of always 404ing. The websocket hub's `broadcast` channel is still dead code — no real-time relay actually happens despite the message-type plumbing existing in `websocket/message.go`.
- ~~**No health-check DB connectivity check.**~~ **Fixed.** `/health` now pings the DB and returns 503 if it's unreachable, instead of a static `{"status":"ok"}`.
- **No graceful shutdown, no structured logging, no DB migrations system** (schema is still just `CREATE TABLE IF NOT EXISTS` at startup — any future schema change needs hand-written migration code), no TLS handling (assumed external, currently undocumented). Not addressed in this pass.
- **CGO build footgun.** The SQLite driver (`mattn/go-sqlite3`) requires `CGO_ENABLED=1` and a C toolchain at build time. Most CI/Docker Go base images default `CGO_ENABLED=0` for static cross-compilation — a naive Dockerfile or GitHub Actions build will fail or silently produce a broken binary unless this is set explicitly. No Dockerfile exists yet (see §5), so this hasn't bitten anyone yet, but will on first containerization attempt.
- **A few fields/routes are scaffolded but dead**: `Run.PlayerID` and `RoomEvent.PlayerID` exist in the models/schema but no controller ever sets them (always empty — looks like per-player attribution for multiplayer runs was planned, not finished), and `RoomEventFracture` is a declared event type with no route/service that ever creates one (only `entered`/`cleared`/`upgrade` are wired). Harmless today, but decide whether to finish or remove before the schema is "final."
- **The client doesn't call this backend at all.** Before investing in hardening it, decide: does v1 ship with server-side stats/leaderboards at all? If yes, this needs auth + validation + rate limiting + an actual hosting target (a VPS, Fly.io, Render, etc.) + the client wired to call it. If no, cut it from the v1 scope entirely and revisit post-launch.

---

## 4. Save data & anti-cheat

- **Currency and unlocks are stored in a plaintext, unencrypted, unsigned `ConfigFile`** (`user://player_profile.cfg`) — any player can open it in a text editor and set `fracture_shards` or any meta-upgrade level to whatever they want in seconds. Low severity for single-player (self-cheating only harms the cheater), but if meta-upgrade bonuses are ever read into a PvP match, this becomes a real competitive-integrity hole.
- ~~**Two overlapping save files.**~~ **Fixed.** `best_stats.cfg` removed — it duplicated `player_profile.cfg`'s best-kills/combo/time/runs fields and both were updated from the same call sites. The "new best!" summary banner now takes the previous best as a parameter instead of loading a second file.
- ~~**Saves are written synchronously and non-atomically.**~~ **Fixed.** New `save_util.gd` (`SaveUtil.save_atomic()`) writes to a `.tmp` file and renames over the real path, used by both remaining save files. A crash or power loss mid-write can no longer produce a torn/corrupted save. Both saves also now carry a `save.version` field for future migrations (nothing reads it yet, it's just in place). Bit-rot or manual corruption of an otherwise-intact file is still handled by falling back to a fresh profile (`_safe_int`/`_safe_float` guards) rather than a full backup/rotation scheme — decide if that's worth adding once there are real players.
- Decide explicitly what the threat model is (this is a single-player/co-op game — is save-editing even worth defending against?) rather than leaving it as an unconsidered gap.

---

## 5. Platform, build, and storefront readiness

- **No LICENSE file** anywhere in the repo — legal terms for the code are currently undefined.
- **No CREDITS/attribution file** — moot today since there are no third-party assets, but required the moment any art/audio/font asset is added under a license that requires attribution.
- **Export presets cover Windows and macOS only** — no Linux, despite Godot supporting it natively at no extra engine cost.
- **Windows build**: no icon set, no code signing. Unsigned Windows executables trigger SmartScreen warnings that meaningfully hurt install conversion for a public release.
- **macOS build**: `codesign/codesign=0` — codesigning is explicitly disabled, and there's no notarization configured at all. An unsigned, non-notarized app will be blocked outright by Gatekeeper on any Mac with default security settings — this isn't a warning, it's a hard block for most users.
- **No export templates configured** (`custom_template/debug` / `custom_template/release` are empty in both presets) — a real export will fail until templates are installed and selected.
- **No CI/CD** — no automated build, test, or lint pipeline (confirmed: zero `.yml`/`.yaml` files anywhere outside `.godot/`). Every export today is a manual, unrepeatable process.
- **No `[rendering]` section pinned in `project.godot`** — the renderer backend is whatever Godot 4.6's default is, never explicitly set; behavior could silently shift on an engine upgrade.
- **Storefront listing requirements** (Steam, itch.io, or any console) — none of this exists yet and all of it is required before a listing can go live: store page copy, capsule/header art, screenshots, a trailer, an age/content rating, a price, a support/contact channel, and (for Steam specifically) a Steamworks integration decision — achievements, cloud saves, leaderboards are all opt-in but expected by genre-savvy players if omitted entirely.

---

## 6. Multiplayer depth (beyond the critical join bug)

- **No NAT traversal or relay.** Even once the join-UI address bug (§1) is fixed, there's no STUN/TURN/UPnP or relay service — real internet play requires the host to manually port-forward, which the vast majority of non-technical players will not do. A relay/matchmaking service (or a hosted lobby service) is effectively required for "play with strangers" to be viable; LAN/same-network play is the realistic ceiling without one.
- **No host migration.** If the host disconnects or crashes, the run ends for every connected client (`game_manager.gd`, host-leave handling) — no fallback host election, no pause-and-wait state.
- **No reconnection support.** A client that drops mid-run cannot rejoin their in-progress player state; rejoining spawns a fresh player.
- **No dedicated-server option** — only listen-server (host is a player). This is a legitimate design choice for a small co-op game, but it means host advantage/host-quit-kills-the-game are permanent characteristics, not bugs to eventually fix — worth stating explicitly in the game's own multiplayer UX/copy so players aren't surprised.
- **Ping/RTT is measured but never shown to players** — no latency indicator anywhere in the HUD.

---

## 7. Content depth & game design

- **Every room is the same arena.** Rooms are procedurally re-populated with obstacles inside one persistent circular arena, not distinct floor plans/level geometry. This gives real *encounter* variety (obstacle placement, enemy mix, hazards) but zero *architectural* variety. For a commercial roguelike this reads as thin — worth at least one or two alternate arena shapes/geometries before launch.
- **5-8 rooms per run, 2 bosses total.** Light content volume for a paid release; comparable genre titles ship substantially deeper room counts and boss variety. This is either a scope decision to make peace with (ship a short, tight, cheap game) or a content backlog to plan for.
- **No pathfinding anywhere** (no `NavigationAgent3D` in the entire codebase) — melee enemies (chaser, tank, dasher, exploder) navigate via straight-line vectors and will visibly get stuck on the very obstacles `room_controller.gd` procedurally places. A player can stand behind a pillar and permanently neutralize every melee enemy type while ranged enemies (which use raycast line-of-sight checks) still function — a real, easily-discovered exploit, not a theoretical one.
- **Boss AI is purely distance-threshold + random** with no memory of recent attacks — both bosses can be reliably kited by staying outside their melee/AoE ranges, which removes attack-pattern variety and makes fights monotonous once discovered.
- **No object pooling anywhere** (confirmed: zero hits for `pool`/`ObjectPool` across `systems/enemy/` and `systems/rooms/`). Every tracer, muzzle flash, slam ring, shockwave, warp particle, hazard zone, and room obstacle allocates a fresh `MeshInstance3D`/`Area3D`/`StandardMaterial3D` at runtime, tweens it, then `queue_free()`s it — repeated every shot, every enemy death, every room transition. There's also no enemy count cap or distance-based LOD/tick-throttling — every live enemy runs full physics + (for shooter/sniper) raycasts every frame regardless of distance from the player. Fine at current small encounter sizes, but a real GC/frame-time risk once content scales up — worth profiling before adding bigger waves, not after players report stutter.
- **Room content is hardcoded procedural-mesh code, not data.** Every obstacle type, hazard, and room layout is a GDScript function that manually constructs meshes/collision/materials (`room_controller.gd`, the single largest file in the project). There's no designer-facing data file or artist-authored scene for room content — adding one new obstacle type means writing ~30-80 lines of mesh-construction code. Real scaling cost for post-launch content updates.
- ~~**Heavy code duplication across 10 enemy controller files.**~~ **Fixed for the 8 standard types** as of the 2026-08-27 rebuild pass — see `enemy_base.gd` and CLAUDE.md's architecture notes. All 8 now share gravity/target/hit-flash/death/arena-clamp/fall-death through a common base class instead of copy-pasting it, and the arena-clamping and fall-death inconsistency this bullet used to describe (only 2 of 10 controllers clamped, only 1 had a fall-death check) is resolved for those 8 — every standard enemy now has both. **The 2 boss controllers were deliberately left out of this pass** (see CLAUDE.md for why) and still duplicate their own boilerplate against each other — worth a `BossBase` pass later, lower priority since it's only 2 files.
- **Doc/code drift**: README's mutation example list includes "neural overload," which doesn't exist in the 8-entry mutation catalog — fix before using the README as marketing copy source material.

---

## 8. UX, accessibility, and localization

- **No key rebinding UI at all** — controls are hardcoded in `project.godot`'s input map with no in-game remapping, despite `game_settings.gd`'s own comment claiming to cover "accessibility."
- **No colorblind modes, no UI text scaling** — zero accessibility features are actually implemented despite being referenced in a comment.
- **No gamepad/controller support** — the input map defines only keyboard/mouse actions.
- **Zero localization readiness** — `tr()` is never called anywhere in the codebase; every UI string is a hardcoded English literal with no translation keys or `.pot`/CSV source. Shipping to any non-English market requires a full string-externalization pass first, not just adding translated text.
- **Onboarding content quality is unverified** — the overlay mechanism (dismiss-on-any-input, shown-once flag) works, but the actual tutorial copy lives in the scene file and wasn't reviewed for clarity/completeness as part of this pass.

---

## 9. QA, testing, and observability

- **Zero automated tests exist** — no GDScript test framework configured (no GUT/gdUnit), no Go `_test.go` files anywhere. Every system (26 upgrades, 8 mutations, 8 enemy types, 2 bosses, 3 game modes, networking) is currently verified only by manual play.
- **No crash reporting or telemetry SDK** (no Sentry/Crashlytics/Bugsnag-equivalent) — if the game crashes for a real player post-launch, there is currently no mechanism to find out.
- **No CI** to catch regressions on changes (see §5).
- **No documented balance/playtesting process** — difficulty tuning appears to be author-intuition-driven; worth a structured playtest pass (external players, not just the developer) before calling difficulty/economy "balanced," especially given the README already claims this.

---

## 10. Legal & compliance

- **No LICENSE** — open-source terms (or explicit "all rights reserved") for the code are undefined.
- **No privacy policy or EULA** — required the moment the backend collects any real user data (even anonymous stats/telemetry), and required by most storefronts regardless of whether you use the backend.
- **No age/content rating prep** (ESRB/PEGI/IARC as applicable) — required by essentially every distribution channel.
- **No third-party licensing/attribution tracking** — not urgent today (zero third-party assets exist), but must be set up the moment any asset, font, sound library, or asset-store purchase is integrated.

---

## 11. Code quality / technical debt (lower urgency, still worth planning for)

- `game_manager.gd` (~1000 lines) and `main_menu.gd` are god objects wiring most of the game's cross-system logic and UI respectively — functional but will get harder to extend safely as more content is added. Consider splitting responsibilities before the next major content pass, not mid-emergency.
- Enemy controllers' shared boilerplate (gravity, authority checks, hit-flash, death visuals) is copy-pasted across 10 files with no common base — see §7 for the gameplay-facing consequence; the maintenance-facing consequence is that every future enemy-wide change is a 10-file manual sweep.
- `player_controller.gd` implements its own remote-player interpolation inline (lines 126-132) that duplicates the standalone `network_interpolator.gd` component almost exactly — pick one and reuse it.
- `InputProvider.get_mouse_motion()` (`input_provider.gd:25-27`) always returns `Vector2.ZERO` — this is intentional (mouse look is event-driven via `_input()`, not polled, and the function says so in a comment), but it does mean the "swap input source for AI/replay" abstraction the file's header comment describes isn't actually wired up for mouse look specifically. Not a bug, just an incomplete abstraction — worth knowing if an AI-input or replay feature is ever built.

---

## Suggested sequencing

If the goal is an actual public release, roughly in this order:

1. ~~Fix the critical bugs in §1~~ — done as of the 2026-08-27 rebuild pass. The pathfinding exploit (§7) and NAT traversal/relay (§6) are the remaining pieces of "real feature work" from this bucket, not one-line fixes — see those sections.
2. Make an explicit **art direction decision** (§2) — this blocks almost everything else that's visible to a player, including all marketing assets.
3. Decide the **multiplayer ambition level** (§6) — LAN/friends-only via a fixed join flow is a much smaller scope than public matchmaking with a relay service; pick one deliberately.
4. Decide whether the backend ships in v1 at all (§3) — if yes, it needs real hardening and client integration; if no, remove it from scope and revisit later.
5. Content pass for depth (§7) sized to whatever launch ambition is chosen (a short premium release vs. a longer early-access-style roadmap).
6. Platform/legal/storefront checklist (§5, §10) — start early, most of it (ratings, store approval, signing certificates) has lead time independent of dev work.
7. Accessibility/localization (§8) and QA/observability (§9) as ongoing hardening, ideally before — not after — the first real external playtest.
