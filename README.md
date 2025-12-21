# RPG Delivery Sim (Godot 4.5.1 Prototype)

Fast one-day prototype for a delivery RPG loop. Focus is on a single job flow,
curfew pressure, and a clean signal-driven architecture for quick iteration.

## Current Gameplay Loop

- Start from Main Menu and spawn into the town.
- Pick up a parcel from a pickup point to start a job.
- Deliver to the dropoff before curfew Press tab to view the dropoff location.
- If outdoors at curfew, a short timer starts, then you get mugged and lose money.
- Enter the inn safe area to avoid curfew mugging.
- Sleep at the inn after the sleep threshold to reset the day (costs money).

## Controls

- Move: WASD or Arrow Keys
- Jump: Space
- Sprint: Shift (stamina drains and regenerates)
- Interact: E
- Pause: Esc
- Package menu: Tab (also uses the `toggle_package_menu` input action)
- Camera: Mouse look, Mouse wheel zoom

## Current Systems and Progress

Gameplay
- Player movement, camera shoulder offsets, zoom, sprint stamina.
- Pickup and dropoff areas with interact prompts and a single active job.
- Curfew timer and mugging when outdoors after curfew.
- Inn safe area and sleep spot to skip to morning for a fee.

UI
- HUD for money, time, carrying status, interact prompt, stamina, and notifications.
- Pause menu and package menu (job status panel).
- Transition fade for sleep and mugging.

Audio / SFX
- Player animation SFX hooks and UI SFX routing (profiles in scripts).

World
- Town scene with pickups, dropoffs, and inn interior/exterior triggers.

## Autoloads (Global State)

- `GameState`: mode switching (MENU, PLAYING, PAUSED, SLEEPING, MUGGED).
- `TimeSystem`: day progression, curfew timer, mugging, morning reset.
- `Jobs`: single active delivery job tracking.
- `PlayerData`: money and carrying state.
- `UIEvents`: HUD notifications and interact prompt bus.

## Scenes (Entry Points)

- `scenes/ui/MainMenu.tscn`: start and quit.
- `scenes/world/World.tscn`: gameplay scene.
- `scenes/player/Player.tscn`: reusable player character.
- `scenes/ui/HUD.tscn`: HUD and pause flow.

## Project Structure

- `scenes/`: world, player, UI.
- `scripts/`: autoload, world, player, UI.
- `assets/` and `audio/`: placeholders for art and sound.

## Non-goals (Prototype Limits)

- No combat, NPC AI, dialogue trees, saving/loading, or full inventory UI.
- One item type, one active job at a time, no multi-job juggling.
- No health/stamina damage systems beyond sprint stamina.

## How to Run

Open the project in Godot 4.5.1 and run. The main scene is
`res://scenes/ui/MainMenu.tscn`.

## Testing Checklist

- Player can move, jump, sprint, and camera behaves.
- Pick up item updates carrying state and job status.
- Delivering increases money and sends HUD notification.
- Curfew mugging resets money and starts a new morning.
- Pause toggles without breaking input or camera.
