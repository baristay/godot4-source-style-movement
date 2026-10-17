# Godot 4 Source-Style Movement

A Source Engine–inspired first-person movement system built from scratch in Godot 4. Ground movement plays like **CS:GO**, air movement (bunny hopping & surfing) closely matches **CS:S**.

## Quick Start

1. Download the latest build from the [Releases](../../releases) page *(coming soon)*, **or** clone the repo and open it in **Godot 4.7**.
2. Run the main scene.

Developed and tested on Godot 4.7. Older versions are untested.

## Controls

| Action | Key |
| --- | --- |
| Move | `W` `A` `S` `D` |
| Jump (hold to bunny hop) | `Space` / `Mouse Wheel` |
| Walk | `Shift` |
| Crouch | `Ctrl` |
| Noclip | `E` |
| Save checkpoint | `Q` |
| Load checkpoint | `R` |
| Turn with keyboard | `←` `→` |
| Gamerule / Map UI | `Esc` |

## Features

- **Custom collision response**: movement and collision handling are written from the ground up instead of relying on Godot's default character physics. Designed to work with imported collision shapes as well as level geometry built in the editor.
- **Two independent state machines:**
  - **Movement:** `Ground`, `Air`, `Noclip`
  - **Crouch:** `Standing`, `Ducking`, `Unducking`, `Ducked`
- **Ground movement** modeled after CS:GO.
- **Air movement** closely matching CS:S (Counter-Strike: Source), including **bunny hopping** and **surfing**.
- **Noclip mode** for free flying through the level.
- **In-game checkpoint system**: save your full movement state (position, velocity, current state machine states, etc.) with a key press and teleport back to it at any time.
- **Gamerule UI** (`Esc`): tweak movement values live while playing: max ground speed, acceleration, and more.
- **Map switcher UI** (also under `Esc`): jump between test maps without restarting.

The core movement system is considered **feature-complete**. Current work is focused on building out maps rather than the movement code itself.

### Not included (possible future additions)

- Crouch sliding
- Wall running
- Ladder climbing
- Crouch interpolation while airborne
- Swimming
- Options menu *(honestly, I got too lazy to build one. The Gamerule UI covers most of what it would have done anyway)*

## Use in your project

1. Copy the `Player` folder anywhere into your project.
2. Open `Player/project_setup.gd` in the script editor and run it via **File → Run**.
   It adds the required input actions (existing ones are skipped) and sets these project settings:
   Jolt Physics, 67 physics ticks per second, physics interpolation on, vsync off.
   **Existing values of these settings will be overwritten.**
3. Restart the editor.
4. Drag `Player/Character.tscn` into any scene with collision geometry. That's it, the movement system is ready to use.

### Tweaking values

All movement defaults live in `Player/resource/movement_config.gd`. Every component reads them from a single shared instance (`MovementConfig.get_shared()`), so changes made through the Gamerule UI at runtime apply everywhere immediately. If you write your own scripts, get the config the same way:

```gdscript
var config: MovementConfig = MovementConfig.get_shared()
```

## Acknowledgements

- This project was imported from one of my other game projects.
- Movement design inspired by Counter-Strike: Source and Counter-Strike: Global Offensive.
- Ground movement was written independently, without referencing the original Source engine source code. For the air movement, I did reference the original CS:S source code after getting stuck on getting the feel right for a long time.
- Prototype textures by [Kenney](https://kenney.nl/assets/prototype-textures) (CC0).

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.