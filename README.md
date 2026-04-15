# Tank3D

A Godot 4 single-player 3D tank battle prototype. Open this folder in Godot, run the project, and play from the generated arena.

## Controls

- `W/S`: move forward and backward
- `A/D`: rotate tank body
- Mouse: aim turret
- Left mouse button: fire
- `Q`: speed boost
- `E`: shield
- `R`: power shot
- `Enter` or `Space`: restart after victory or defeat

## What Is Included

- Start menu, settings panel, ranking panel, in-game HUD, victory panel, and defeat panel
- Persistent music/sound settings, enemy fire-frequency difficulty (`Normal`/`Aggressive`/`Elite`, default `Normal`), and top-10 ranking data saved under Godot `user://`
- Runtime-generated 3D arena with floor, walls, and cover
- Player tank with `CharacterBody3D` movement and mouse-aimed turret
- Projectile physics with collision damage
- Enemy tanks with human-like tactical states, robust fire-control logic, tiered fire-frequency difficulty (`Normal`/`Aggressive`/`Elite`), guaranteed 3-second opening suppressive fire in elite mode, active hunt behavior, last-known-position pursuit, predictive aiming with aim adjustment, line-of-sight checks, close-range pressure, burst fire, short-window suppressive fire, retreat behavior at low health, hit response, strafing, obstacle avoidance, projectile dodging, flanking anchors, and firing cooldowns
- Health system and world/screen health bars
- Score and clear-time tracking
- Three-skill system with cooldown HUD
- Smooth follow camera with a configurable orthographic mode
- Procedural looping battle music generated at runtime, with no external audio assets required

The previous Unity prototype is still present under `Assets/` for reference. The active Godot version follows the same high-level product structure as the referenced Tank Battle design: panel-driven UI, data persistence, ranking, background music management, battle scoring, and tank combat logic. Generated meshes and materials keep the prototype easy to replace with imported tank models, textures, effects, and sounds later.
