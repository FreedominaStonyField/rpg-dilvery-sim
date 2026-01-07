# RPG Dilvery Sim (Prototype)

A fast Godot 4.5.1 prototype for a delivery-focused RPG loop.
Keep changes small, signal-driven, and easy to extend tomorrow.

## Scope (One-Day Prototype)
- One item type and one active job at a time
- Curfew system with mugging if outside the safe zone
- Inn for sleeping to advance time
- Courier journal shows active job, offers, and completed jobs with snapshots
- Dropoff snapshots use SubViewport capture sized to the player viewport
- Inventory menu is lightweight (view + discard) and pauses play
- Save hooks run on sleep and job completion



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
- Package menu (Courier Journal): Tab
- Inventory menu: I
- Unstuck: U

## Architecture Notes
- Single-responsibility scripts in `scripts/`.
- Cross-node communication uses signals.
- Global state lives only in autoloads:
  - `GameState`: mode state (MENU, PLAYING, PAUSED, SLEEPING, MUGGED)
  - `TimeSystem`: day progression and curfew events
  - `Jobs`: single active delivery job
  - `PlayerData`: money and carrying state
  - `InventorySystem`: delivery item tracking + simple inventory list
  - `UIEvents`: HUD event bus
  - `SaveSystem`: auto-save hooks for sleep and jobs
- Job completion data is stored as `JobRecord` resources for reuse in UI/history.

## Systems and Intended Use
- `GameState`: gate input and UI; menus pause play and set mouse visible.
- `TimeSystem`: advances day time, fires curfew events, and resets on sleep.
- `Jobs`: builds job offers, starts the active job, tracks completion snapshots.
- `PlayerData`: stores money and emits change signals for HUD updates.
- `InventorySystem`: stores the delivery item and simple inventory list (discardable only).
- `UIEvents`: central UI message bus for prompts, menu toggles, and notifications.
- `SaveSystem`: saves current money/job state on sleep and job completion.

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
- Dropoff 3D labels use `display_name` when set

## Testing Checklist
- Player can move and camera behaves
- Pickup updates carrying state
- Deliver increases money and HUD notifies
- Curfew mug resets money and advances to morning
- Pause toggles without breaking input
- Completed job appears in journal list with snapshot/hint
- Snapshot shows the correct dropoff view and matches scene lighting/sky
