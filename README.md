## rush-fracture

quick note before anything else: i started this project without knowing gdscript. this project is co-developed with claude, which helped me learn godot scripting, structure systems properly, and assist with testing and validation throughout development.

---

## what this is

rush-fracture is a fast-paced fps roguelike built in godot, with procedural runs, build variety, and both co-op and competitive multiplayer.
the focus is on movement, quick decision-making, and replayability rather than high-end visuals.

---

## current state

the project is fully playable.

- single-player works  
- multiplayer (co-op and competitive) works  
- procedural runs are stable  
- core systems are complete  

you can start the game, play full runs, fight bosses, and restart without issues.

---

## core gameplay loop

- start a run  
- clear rooms  
- pick upgrades and mutations  
- adapt your build  
- survive events and enemies  
- reach boss or encounter another player  
- finish and restart  

each run is short but will feel different.

---

## movement and combat

- fast fps movement with dash and air control  
- momentum-based feel  
- three weapon types:
  - pulse rifle (balanced)
  - scatter cannon (close range)
  - beam emitter (continuous damage with heat)

- weapon switching during combat  
- hit feedback, recoil, screen shake  
- combo system based on consecutive kills  

---

## build system

each run builds differently.

### upgrades
- weapon-specific modifiers (burst, chain, ricochet, etc.)
- global modifiers (damage, speed, cooldown)

### mutations
- stronger effects with downsides  
- examples:
  - glass cannon
  - momentum shield
  - fracture echo  

these affect how you approach the run.

---

## enemies

multiple enemy types with different behaviors:

- chaser  
- shooter  
- tank  
- exploder  
- sniper  
- support  
- displacer  

enemy combinations vary depending on room type and difficulty.

---

## bosses

- fracture titan (main boss with phases)  
- fracture warden (mid-run mini boss)  

bosses are designed to be readable but still challenging.

---

## room system

procedural but structured:

- combat rooms  
- swarm rooms  
- elite rooms  
- recovery rooms  
- hazard rooms  
- gauntlet rooms (waves)  
- elite chamber (mini boss)  

room sequences are generated per run with scaling difficulty.

---

## fracture events

temporary modifiers that change gameplay:

- low gravity  
- increased enemy speed  
- random explosions  
- vision distortion  
- enemy duplication  

they add variation without completely breaking balance.

---

## multiplayer

multiplayer is fully integrated.

### co-op
- shared run  
- synchronized enemies and progression  

### race mode
- players progress separately  
- meet later in the run  

### pvp encounter
- players fight each other using their builds  
- outcome depends on earlier decisions  

---

## networking

- host and client model  
- server authority for enemies and damage  
- interpolation for smooth movement  
- basic latency handling  
- stable enough for local and small-scale testing  

---

## progression

basic persistence:

- total runs  
- total kills  
- best combo  
- wins  

planned and partially implemented:

- currency system  
- unlockable upgrades  
- starting bonuses  

---

## ui and feedback

- hud for weapon, combo, room, and mode  
- simple animations and transitions  
- audio feedback for combat and events  
- debug overlay (toggleable)  

---

## architecture

the project is structured with scalability in mind:

- modular systems (combat, rooms, enemies, upgrades, networking)  
- strict typing across scripts  
- base classes for shared behavior  
- signal-driven communication  
- multiplayer considered from early stages  

---

## running the project

1. open the project in godot (4.x)  
2. run the main scene  
3. optionally run backend for stats tracking  
4. host or join a session  
5. play  

---

## notes

this project started as a learning exercise and grew into a complete playable system.
it is not meant to be a finished commercial product, but it for sure is stable, testable, and extendable.
the main goal was to build something functional, learn along the way, and keep it enjoyable to work on.

will keep adding more features as i keep on learning game-development. thanks.