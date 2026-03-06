# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working Style

The user prefers to write all code themselves. **Do not write or edit GDScript code.** Instead, explain what to implement, which file/function to modify, and what logic to use — then let the user do the typing.

I should feel free to read and open files, though.

## Project Overview

**TLFG** is a platform fighter game built with Godot 4.6 (Forward Plus renderer). The project is evolving from a 2D system (using `CharacterBody2D`) toward a 3D system (`CharacterBody3D`) in the `Game/` directory. Both systems coexist. Viewport is 380×120 stretched to 1280×720 (pixel art).

## Running the Game

Open the project in Godot 4.6 and press F5 (or use the Play button). There are no CLI build commands — everything goes through the Godot editor.

## Architecture

### Autoloads (Singletons)

- **`MultiplayerInput`** (`addons/multiplayer_input/`) — wraps Godot's Input singleton to support per-device input (keyboard + multiple gamepads). Used via `DeviceInput` instances.
- **`DamageDirector`** (`DamageDealing/DamageDirector.tscn`) — a node that emits a `damage` signal. 2D characters connect to it to receive damage notifications.

### 2D Character System (`Characters/`)

`AbstractCharacter` (`CharacterBody2D`) is the base for all playable characters. It owns a `CharacterController` (RefCounted) which:
- Wraps a `DeviceInput` to handle per-player input device binding
- Drives the character by calling `make_jump()`, `make_jump_cut()`, `make_dash()`, `make_attack()` on the body
- Implements an **input buffer** (16-frame leniency) for actions listed in `bufferable_actions`

Characters implement their behavior by overriding the `make_*` methods. Currently: `Archer` (fires arrows) and `Wizard`.

Gravity/jump are calculated from `jump_height` and `time_to_jump_apex` exports, supporting variable jump height via tweens and coyote time.

### 3D Character System (`Game/`)

`player_3d.gd` (`CharacterBody3D`) is the current active 3D platfighter prototype. It uses:
- **`MovementStats`** (Resource) — exports for ground speed, dash, air, and jump params. Call `compute_jump_values()` to derive `gravity_up`, `gravity_down`, `jump_speed` from `jump_height` and `time_to_apex`.
- **`CombatStats`** (Resource) — `base_knockback`, `knockback_scaling`, `attack_damage`, `stocks`.
- **`PlayerInput`** (Resource) — string action names (`left_action`, `right_action`, `jump_action`, `attack_action`) used with `Input.get_action_strength()`.

Movement uses a manual slide loop (`move_and_collide` with `max_slides`) rather than `move_and_slide()`. States: `IDLE` (transitions to `DASH` on input) and `DASH` (supports dash-dancing). Hitstun is a float timer that blocks input during knockback.

### Damage System

**2D:** `Hitbox` (Area2D) hits `Hurtbox` (Area2D). `Hurtbox` calls `take_damage(damage)` on its `who_to_damage` node. `Hitbox` supports `hit_effects: Array[HitEffect]` triggered on contact. RID tracking prevents multi-hit.

**3D:** `Hitbox3D` (Area3D in `Game/hitbox.gd`) — activated via `activate()`, briefly enables monitoring, calls `apply_knockback(direction, damage)` on hit bodies. Direction and damage are exports.

### Effect System

- **`AbstractEffect`** (Resource) — base class. `trigger(node)` instantiates `EffectScene` at the node's position in the scene tree root.
- **`CharacterEffect`** (Resource) — same pattern but adds to `current_scene` instead of root.
- Effects are composed via export arrays on characters: `walk_effects`, `hit_effects`, etc.

### Enemy System (`Enemies/`)

`AbstractEnemy` (`CharacterBody2D`) — state machine with `Idle`, `Walking`, `PlayerDetected`, `Attacking`, `Attacking2`, `Dead`. Uses `action_timer` to pick random wander states. Enemies implement `take_damage(float)` to integrate with the `Hurtbox` system.

### Input Mapping

2D physics layers: `World` (1), `Player` (2), `Enemy` (3), `Hitbox` (4), `Hurtbox` (5).

Input actions follow a `p{N}_{action}` naming pattern (e.g., `p1_move_left`, `p2_jump`). The `MultiplayerInput` addon remaps these per device automatically.

### Addons

- **`aseprite_importer`** — imports Aseprite files as sprite sheets/animations.
- **`multiplayer_input`** — device-aware input abstraction. Use `DeviceInput` (not raw `Input`) inside `CharacterController` for local multiplayer support.
