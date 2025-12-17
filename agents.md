# AGENTS.md - Godot 4.5.1 Prototype Rules (One-Day Delivery RPG)

This repo is a fast prototype. Code must be consistent and easy to extend tomorrow.

## 1) Non-goals (Do NOT build)
- No combat, no NPC AI, no dialogue trees
- No saving/loading
- No full inventory UI (HUD only)
- No health/stamina/fall damage system today
- No multi-job juggling today

## 2) High-level architecture
Use small single-responsibility scripts and communicate with **signals**.
Global state lives in **autoload singletons** only.

### Autoloads (Singletons)
- `GameState`: controls current mode (MENU, PLAYING, PAUSED, SLEEPING, MUGGED)
- `TimeSystem`: day progression + curfew events
- `Jobs`: manages the single active delivery job
- `PlayerData`: money + carrying state
- `UIEvents`: one-line event bus for HUD notifications (optional but recommended)

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

### Required formatting
- 4 spaces indentation (no tabs)
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
  - If indoors: safe (no mugging)
- Inn:
  - Entering inn pauses time progression
- "Sleep" sets morning and resumes play

## 8) Testing discipline
Every change must keep these working:
- Player can move + camera behaves
- Pick up item -> carrying state updates
- Deliver -> money increases + HUD notify
- Curfew mug -> money resets -> morning
- Pause toggles without breaking input

## 9) Output format for codegen agents
When generating code, ALWAYS output:
1) File tree showing new/changed files
2) Each file content in a fenced code block with correct path label
3) Brief note on how to wire autoloads in Project Settings if needed
