# AGENTS.md - Godot 4.5.1 Prototype Rules (One-Day Delivery RPG)

This repo is a fast prototype. Code must be consistent and easy to extend tomorrow.

## 1) Current scope (Not hard limits)
These describe the current prototype state, not permanent feature limits.
If a task requests expanding beyond this list, update the list as part of the change.
- No combat, no NPC AI, no dialogue trees
- No saving/loading system beyond current save hooks
- No inventory system yet (rebuild planned)
- Stamina is a HUD placeholder (no exhaustion penalties yet)
- No health/fall damage system yet
- No multi-job juggling yet

## 2) High-level architecture
Use small single-responsibility scripts and communicate with **signals**.
Global state lives in **autoload singletons** only.
Favor node composition over inheritance: build behavior from sibling/child nodes
and small helper scripts instead of deep class trees.

### Autoloads (Singletons)
- `GameState`: controls current mode (MENU, PLAYING, PAUSED, SLEEPING, MUGGED)
- `TimeSystem`: day progression + curfew events
- `Jobs`: manages the single active delivery job
- `PlayerData`: money + carrying state
- `UIEvents`: one-line event bus for HUD notifications (optional but recommended)
- `SaveSystem`: save hooks for sleep and job completion

No other singleton globals.

## 3) Project structure
Use this layout:

- `scenes/`
  - `ui/`
  - `world/`
  - `player/`
- `scripts/`
  - `autoload/`
  - `ui/`
  - `world/`
  - `player/`
- `assets/` (placeholder until real assets arrive)
- `audio/` (optional)

Every scene should have a script ONLY if it contains logic.

## 4) GDScript style
- Godot 4.x typed GDScript where it helps readability, but don't fight the engine.
- Use `snake_case` for variables/functions.
- Use `PascalCase` for classes and node names.
- Prefer `@onready var` for node refs.
- Prefer exported node paths for configurable references.
- Prefer composition: add nodes for behavior (e.g., `Area3D`, `Timer`, `RayCast3D`)
  instead of inheriting new base classes.
- Keep scripts focused on one concern and wire them together via signals.
- Example: `PickupTrigger.tscn` with `Area3D` + `CollisionShape3D` + `AudioStreamPlayer3D`
  and a `PickupTrigger.gd` script that emits `picked_up`, while a separate `CarryState.gd`
  listens and updates `PlayerData`.

### Required formatting
- Tabs for indentation (GDScript tab indents)
- Max line length ~100
- One class per file
- No giant "manager god scripts"

### Comments
- Short "why" comments only.
- No tutorial-style essays in code.

## 5) Signals and events
- Use signals for cross-node communication.
- Autoloads can emit global signals (e.g., `TimeSystem.curfew_started`).
- UI listens to `UIEvents` or direct signals.

## 6) Scene conventions
- Player scene is reusable:
  - `CharacterBody3D` root
  - child: `SpringArm3D` + `Camera3D`
- World scene contains:
  - `NavigationRegion3D` (optional)
  - Dropoff points + pickup triggers
  - Inn entrance trigger + interior safe zone

## 7) Prototype gameplay rules
- One item type
- One active job at a time
- Curfew:
  - If outdoors when curfew hits: start a short timer, then mug.
  - If in safe zone: safe (no mugging)
- Inn:
- "Sleep" sets morning, saves money, and resumes play

## 8) Current systems and intended use
- `GameState` gates input; menus pause play and show the mouse cursor.
- `TimeSystem` controls day time, curfew, and morning reset.
- `Jobs` builds offers at pickups, tracks the active job, and emits snapshots.
- `PlayerData` owns money and notifies HUD updates.
- `UIEvents` is the UI event bus for prompts, menus, and notifications.
- `SaveSystem` performs auto-save hooks on sleep and job completion.

## 9) Testing discipline
Every change must keep these working:
- Player can move + camera behaves
- Pick up item -> carrying state updates
- Deliver -> money increases + HUD notify
- Curfew mug -> money resets -> morning
- Pause toggles without breaking input

## 10) Output format for codegen agents
When generating code, ALWAYS output:
1) Summary of systems and methods to test each part.
