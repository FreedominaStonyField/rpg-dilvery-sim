# RPG Dilvery Sim (Prototype)

A fast Godot 4.5.1 prototype for a delivery-focused RPG loop.
Keep changes small, signal-driven, and easy to extend tomorrow.

## Scope (One-Day Prototype)
- One item type and one active job at a time
- Curfew system with mugging if outside the safe zone
- Inn for sleeping to advance time
- Courier journal shows completed jobs with snapshot + hint history

## Non-Goals
- No combat, NPC AI, or dialogue trees
- No save/load system
- No full inventory UI (HUD only)
- No health, stamina, or fall damage
- No multi-job juggling

## Requirements
- Godot Engine 4.5.1

## Quick Start
1. Open `project.godot` in Godot 4.5.1.
2. Run the project (main scene is `scenes/ui/MainMenu.tscn`).

## Controls
- Move: WASD or arrow keys
- Sprint: Shift
- Jump: Space
- Interact: E
- Pause: Esc
- Package menu: Tab
- Unstuck: U

## Architecture Notes
- Single-responsibility scripts in `scripts/`.
- Cross-node communication uses signals.
- Global state lives only in autoloads:
  - `GameState`: mode state (MENU, PLAYING, PAUSED, SLEEPING, MUGGED)
  - `TimeSystem`: day progression and curfew events
  - `Jobs`: single active delivery job
  - `PlayerData`: money and carrying state
  - `UIEvents`: HUD event bus

## Key Scenes
- `scenes/ui/MainMenu.tscn`: main menu entry
- `scenes/ui/HUD.tscn`: HUD and notifications
- `scenes/world/World.tscn`: world, pickups, dropoffs, inn triggers
- `scenes/player/Player.tscn`: player character (CharacterBody3D + SpringArm3D + Camera3D)

## Project Layout
- `scenes/`
  - `ui/`, `world/`, `player/`
- `scripts/`
  - `autoload/`, `ui/`, `world/`, `player/`
- `assets/`, `audio/`

## Prototype Gameplay Rules
- One active job at a time
- Curfew: if outside, short timer then mugged
- Safe zone prevents mugging
- Sleeping sets morning, saves money, resumes play
- Job completion pops up the journal entry, fades out, and can play per-dropoff audio

## Testing Checklist
- Player can move and camera behaves
- Pickup updates carrying state
- Deliver increases money and HUD notifies
- Curfew mug resets money and advances to morning
- Pause toggles without breaking input
- Completed job appears in journal list with snapshot/hint
