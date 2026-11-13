class_name Layers
extends RefCounted

# physics layer bits, named once so nothing else hard-codes mask numbers.

const WORLD: int = 1       # floor, walls, obstacles, platforms
const ENEMY: int = 2       # enemy and boss bodies
const PLAYER: int = 4      # player bodies
const PICKUP: int = 8      # pickup trigger volumes

## what a player's weapon ray can hit
const SHOT: int = WORLD | ENEMY
## what an enemy's line-of-sight ray can hit
const SIGHT: int = WORLD | PLAYER
