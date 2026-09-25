# Godot 4 Source-Style Movement

A Source Engine–inspired first-person movement system built from scratch in Godot 4. Ground movement plays like **CS:GO**, air movement (bunny hopping & surfing) matches **CS:S** 1:1.

## Features

- **Custom collision response** — the movement and collision handling are written from the ground up, not just Godot's default character physics. Works correctly with all collision types, including collisions from imported objects, not just level geometry built in the editor.
- **Two independent state machines:**
  - **Movement:** `Ground`, `Air`, `Noclip`
  - **Crouch:** `Standing`, `Ducking`, `Unducking`, `Ducked`
- **Ground movement** modeled after CS:GO-style movement.
- **Air movement** matching CS:S (Counter-Strike: Source) 1:1, including **bunny hopping** and **surfing**.
- **Noclip mode** for free flying through the level.
- **In-game checkpoint system** — save your full movement state (position, velocity, current state machine states, etc.) with a key press and teleport back to it at any time. Think of it as a checkpoint save/load for movement.
- **Gamerule UI** (opened with `Esc`) — tweak movement values live while playing: max ground speed, acceleration, and more.
- **Map switcher UI** (also under `Esc`) — jump between test maps without restarting.

## Requirements

- Godot Engine **4.7**

Clone the repo, open the project folder in Godot 4.7, and run the main scene. No exported build is provided yet — the project is meant to be run from the editor. *(An exported build may be added later.)*

Controls are shown in-game when you start playing, so you won't need to memorize anything up front.

The core movement system is considered **feature-complete**. Current work is focused on building out test maps rather than the movement code itself.

### Not included (possible future additions)

- Crouch sliding
- Wall running
- Ladder climbing
- Crouch interpolation while airborne
- Swimming
- Options menu *(honestly, I got too lazy to build one. The Gamerule UI covers most of what it would have done anyway)*

## Acknowledgements

Movement design inspired by Counter-Strike: Source and Counter-Strike: Global Offensive. Ground movement was written independently, without referencing the original Source engine source code. For the air movement, I did reference the original CS:S source code after getting stuck on getting the feel right for a long time.

## License

This project is licensed under the **MIT License** — see the LICENSE file for details.
