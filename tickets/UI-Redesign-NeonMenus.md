# Ticket: UI Redesign Pass (Neon / Glass Panels + Fade Timings)

## Goal
Update only the UI currently used by the game to match the new menu mockups (neon, semi-transparent “glass” panels), and standardize fade/transition timings for in-game UI.

## Design References
- Main menu: holographic left-side panel over city background
- Pause menu: centered neon panel stack
- Courier journal/job board: tabbed glass window (Current Manifest / Job Board / History)
- Curfew violated: red alert panel with “stolen” callout + continue CTA
- Objective complete: gold celebration panel + “Complete mission” CTA
- In-game HUD: minimal top HUD + subtle prompt + curved stamina bar (only if stamina exists)

## In Scope (Used UI Only)
- `scenes/ui/MainMenu.tscn` + `scripts/ui/main_menu.gd`
- `scenes/ui/HUD.tscn` + `scripts/ui/hud.gd`
	- Pause menu (Esc)
	- Courier Journal / Package menu (Tab)
	- Notifications (UIEvents)
	- Interaction prompt/panel (UIEvents.register_interaction)
	- Sleep + mug transitions (TimeSystem/UIEvents)
- `scenes/ui/WinScreen.tscn` + `scripts/ui/win_screen.gd`

## Out of Scope (Do NOT Implement)
- Any UI not reachable from current gameplay loop
- New settings/options screens (none currently used)
- Pause-menu “Load Game” (not currently present in pause flow)
- Debug-only UI (`AnimationDebug` panel)
- Stamina HUD redesign if the player does not emit `stamina_changed` in-game yet

## Visual/UX Requirements
- Semi-transparent panels: use glass-style `StyleBoxFlat` (alpha background + neon border)
- Consistent spacing: 8/12/16 px padding system; avoid dense text blocks
- Clear hierarchy: large title, short subtitle, primary CTA, secondary actions
- Button states: normal/hover/pressed with distinct neon glow/contrast
- In-game UI fade timings: configurable and consistent across HUD elements

## Fade/Timing Requirements
- Define shared timing constants (or exported vars) for:
	- HUD notifications (fade in/out + hold)
	- Journal open/close and auto-flash fade-out
	- Pause menu open/close
	- Sleep/mug overlay transitions
- Ensure no UI “pops” on/off in PLAYING mode; use tweens for alpha/position where appropriate

## Implementation Notes
- Prefer a shared `Theme` resource and reusable `StyleBoxFlat` subresources (single source of truth)
- Keep code signal-driven (no new singletons)
- Avoid adding new gameplay logic; this ticket is visual/UX + timing only
- Ensure mouse/focus behavior remains correct (Tab journal, Esc pause, list focus, etc.)

## Acceptance Criteria
- Main menu matches the mock layout and uses semi-transparent panel styling
- HUD elements use semi-transparent panels and consistent typography/colors
- Courier Journal visually matches the “glass window” design (tabs optional only if mapped to existing sections)
- Pause menu matches the new design and preserves existing actions (Resume/Save/Quit to Title)
- Mug/sleep overlays match new styling and respect fade durations (no hard cuts)
- Win screen reflects “Objective complete / City Pass acquired” presentation without breaking credits flow
- No unused UI from mockups is added if it’s not reachable in the current loop

## Test Plan (Must Keep Working)
- Player can move + camera behaves
- Pick up -> inventory updates -> HUD money + journal updates
- Tab toggles Courier Journal; offers selectable/accept works; focus/scroll works
- Deliver -> money increases + HUD notification fades correctly
- Curfew mug -> overlay plays -> money resets -> morning
- Inn sleep -> overlay plays -> morning
- Esc pause toggles without breaking input; Resume/Save/Quit works
- Buy City Pass ($5,000) -> Win screen -> return to main menu

## Est. Effort
- 3–6 hours (theme + scene layout + polish)
