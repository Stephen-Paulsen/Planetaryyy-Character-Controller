# Planetaryyy Character Controller

A work-in-progress, physics-driven character controller for my future Godot projects. The project explores responsive movement in environments with spherical planets and non-standard gravity, with an emphasis on how a character's body reacts to the surface and to movement.

**Engine:** Godot  
**Language:** GDScript  
**Status:** In development / experimental

> This repository contains a character-controller prototype, not a finished standalone game. Some movement and animation systems are still being refined.

## Project goals

Planetaryyy explores a different feel from a conventional first-person controller. Instead of keeping the character capsule upright in world space, the controller adjusts its orientation in relation to local gravity. The broader design goal is to make baseline human movement feel physically limited, so later movement upgrades can feel meaningful.

## Current systems

- **Movement and camera controls:** running, jumping, crouching, mouse look, camera switching, and leaning.
- **Surface-relative orientation:** the controller uses the gravity direction to determine its current up direction, allowing it to orient around spherical planets.
- **Ground and surface detection:** a short-range ground raycast checks the nearby surface for grounded movement, while a longer-range raycast helps detect a surface in the direction of gravity.
- **Separate elevation and rotation control:** elevation and orientation are adjusted independently, each with its own PID controller for fine corrections.
- **Grounded and airborne behaviour:** orientation behaviour can differ depending on whether the character is grounded or airborne. A configurable thruster-style mode is intended to allow more controlled orientation while moving through air or space.
- **Physics-driven character body:** the controller's collision body and movement react physically rather than behaving like a mostly upright, static FPS capsule.

## Foot placement and procedural movement

The stepping system is a work in progress.

The current approach constrains movement using foot contact and leg reach: movement should not proceed unless at least one foot is stepping and the leg is not extended beyond its allowed length. The controller can currently feel smooth, but it still relies heavily on floating movement, and this can conflict with the inverse-kinematics (IK) leg animation.

Work remains on making the gait feel more natural, including choosing which foot should move next, coordinating leg movement with the hips and upper body, and adding stride-related body motion. The more detailed movement sequence is a design goal, not a completed feature.

## Controls

| Action | Default input |
| --- | --- |
| Move forward | `W` |
| Move backward | `S` |
| Move right | `D` |
| Move left | `A` |
| Jump | `Space` |
| Crouch | `Ctrl` |
| Run | `Shift` |
| Helmet HUD | Mouse thumb button 2 |
| Change camera | Mouse thumb button 1 |
| Left click | Left mouse button |
| Right click | Right mouse button |
| Lean right | `E` |
| Lean left | `Q` |

If your mouse does not have thumb buttons, change those bindings in the Godot project settings. A dedicated in-game control-remapping menu is a possible future improvement.

## Open development goals

- Use the ground surface normal alongside gravity direction to improve alignment on sloped terrain.
- Continue refining procedural footstep selection, foot placement, and coordination with IK animation.
- Improve the relationship between stepping, body movement, and the character's forward or sideways travel.
- Explore additional surface-relative movement modes. Wall or ceiling traversal is a possible direction, not a currently completed feature.
- Consider adding in-game control remapping.

## Open the project

1. Clone or download this repository.
2. Open `project.godot` in the Godot editor.
3. Run the configured project from the editor.

The controller is under active development, so controls and implementation details may change.

## Licensing

### Source code

The source code and game logic are licensed under the **GNU General Public License v3.0 (GPL-3.0)**. You may modify, fork, and use the code commercially under the terms of that license. Derivative works that distribute the covered source code must comply with GPL-3.0.

### Creative assets

Unless explicitly stated otherwise, non-code creative assets in this repository remain the exclusive intellectual property of Stephen Paulsen and are **all rights reserved**. This includes visual artwork, textures, sprites, UI elements, 3D models, music, audio, dialogue, story material, character concepts, and compiled game-data packages.

The GPL-3.0 grant applies to the software source code, not to those reserved assets. If you fork the repository to build another game, remove or replace the reserved assets unless you have obtained separate permission to use them.
