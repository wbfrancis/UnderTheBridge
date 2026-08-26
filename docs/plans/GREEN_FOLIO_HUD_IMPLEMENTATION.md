# Green Folio HUD implementation plan

> Status, 2026-08-25: `PLAYBACK_AND_ACTION_CHAINS_IMPLEMENTATION.md` supersedes this historical plan's fixed four-tile queue and last-nonzero-speed pause details. The approved Green Folio composition and all other visual decisions remain in force.

## Goal

Replace the temporary top-heavy UI in the current playable prototype with the approved Green Folio Bottom HUD. Keep the existing world, camera, commands, simulation, and debug scenarios working.

The implementation must use the project vocabulary in `CONTEXT.md`. Internal names and tests must say **Inspected Patron**, even if the approved display copy says `June selected`.

## Visual source

Use this approved mockup as the visual reference:

`/Users/wfrancis/.codex/visualizations/2026/08/25/01a0370f-4282-7d73-a14d-56efea4a5f41/hud-skeuomorphic-studies.html`

Do not use `hud-green-folio-revision.html`. That broader rebuild was rejected because it changed the approved proportions and made the HUD cramped.

The approved direction is:

- 1990s CRPG skeuomorphism, called **Green Folio**.
- Vintage green `#367055`, cream paper, dark wood, and muted brass.
- A strong outer Bottom HUD frame, with raised treatment reserved for controls.
- A large numbered analog Night Clock.
- Thick progress fills.
- Character names directly below their HUD portraits.
- Action Tiles without a horizontal drop shadow.
- Icon-first controls, with text in hover help where an icon is not clear.

Do not add a minimap. Do not redesign the accepted composition.

## Current implementation

The main scene is `scenes/prototypes/ticket16_presentation_review.tscn`. It uses `scripts/prototypes/perception_greybox.gd` as both the world adapter and UI builder.

The current HUD starts at `_build_hud()` in `scripts/prototypes/perception_greybox.gd`. It creates:

- permanent scenario buttons across the top;
- `+1s`, `+5s`, Play, Debug, Emote Text, and UI Scale controls;
- a large debug panel;
- a separate Patron Info Panel;
- an Action Queue panel that hides when the queue is empty.

The current runtime already provides:

- Night state through `GameSession.snapshot()`;
- player-readable Patron state through `GameSession.patron_view()` and `normal_patron_views`;
- Action Queue state through `CultistCommandSystem.snapshot()`;
- selection and inspection in `perception_greybox.gd`;
- urgent presentational state through `EmoteDirector`;
- camera projection and HUD avoidance through `EmoteOverlay`.

Do not duplicate gameplay state in the new HUD. The HUD reads snapshots and emits player intent.

## Scope

Implement the HUD in the current main scene first. Do not restyle the isolated slice and spike screens in this change.

This work includes:

- the Bottom HUD and Action Tiles;
- Night Clock, Night progress, pause, and speed controls;
- keyboard shortcuts `1`, `2`, `3`, and Space;
- the Inspected Patron selected and empty states;
- anchored Settings and Developer menus;
- the Pause Menu opened by Escape;
- Outcome Modals with Restart and Quit;
- Offscreen Indicators for urgent actors;
- removal of the old permanent top controls and debug panel.

This work does not include:

- new gameplay rules;
- new Patron information;
- a minimap;
- a new camera model;
- finished portrait art;
- a full title screen;
- restyling every test harness.

## Module design

### BottomHud module

Add:

- `scenes/ui/bottom_hud.tscn`
- `scripts/presentation/bottom_hud.gd`
- `resources/ui/green_folio_theme.tres`
- `assets/ui/green_folio/icons/` for the small exported SVG icons used by the HUD

`BottomHud` is one deep presentation module. Its interface is:

```gdscript
signal intent_submitted(kind: StringName, payload: Dictionary)

func render(view: Dictionary) -> void
```

The module owns node visibility, text, progress fills, pressed states, menus, hover help, the analog clock drawing, and modal presentation. The world adapter does not reach into child controls.

Use one intent signal instead of one signal for every button. Document and handle these intent kinds in one `match` in the world adapter:

- `set_time_scale` with `{value: 1.0 | 2.0 | 4.0}`
- `toggle_pause`
- `cancel_active_action` with `{action_id}`
- `remove_pending_action` with `{action_id}`
- `close_inspected_patron`
- `open_pause_menu`
- `resume_night`
- `restart_night`
- `quit_game`
- `select_scenario` with `{scenario_id}`
- `advance_debug_time` with `{seconds}`
- `set_debug_visible` with `{enabled}`
- `set_emote_labels` with `{enabled}`
- `set_ui_scale` with `{scale}`

The `view` dictionary must contain only display-ready, player-readable data:

```gdscript
{
  selected_cultist = {
    id, name, portrait, tint, activity, inspected_patron_status
  },
  action_tiles = [
    {id, icon, label, target_label, active, cancellable, progress_ratio}
  ],
  night = {
    clock_label, closing_label, remaining_label, progress_ratio,
    time_scale, last_nonzero_scale, paused, phase
  },
  inspected_patron = {}, # empty, or sanitized Patron display data
  outcome = {
    visible, kind, cause, captures, capture_quota, progress_ratio
  },
  developer = {visible, scenario_id, scenarios},
  settings = {emote_labels, ui_scale},
  pause_menu_open = false,
}
```

Build this view in one `_hud_view(...)` function in `perception_greybox.gd`. Do not add another pass-through module for it. The view must use `patron_view()` or `normal_patron_views`; it must never use `debug_patron_views` for player-facing Patron data.

### Extend the existing command seam

The Action Queue design requires active Action cancellation, but `CultistCommandSystem` currently exposes only `remove_pending()`.

Add this small interface to `scripts/actions/cultist_command_system.gd`:

```gdscript
func request_cancel_active(cultist_id: StringName) -> Dictionary
```

It must:

- reject an absent or committed active Action with a visible reason;
- call the existing queue cancellation operation when cancellation is allowed;
- release the active reservation;
- start the next pending Action;
- return a display-ready result;
- keep all cancellation rules inside `CultistCommandSystem`.

Extend the normal command snapshot Action view with `cancellable`. Do not expose hidden gameplay data.

For the active Action Tile fill, add a normalized navigation progress query to `NavigableActor3D`. Record the planned path distance when navigation starts, then return completed distance divided by planned distance, clamped to `0.0...1.0`. The world adapter may attach this ratio only when the active navigation action identifier matches the active Action identifier. Use `null` when no stable progress exists; the tile then shows an active state without a fake percentage.

Do not move navigation progress into `GameSession`. It is presentation and navigation state, not a gameplay rule.

### Deepen EmoteOverlay for Offscreen Indicators

Extend `scripts/presentation/emote_overlay.gd` instead of creating a second projection system. It already owns camera projection, actor anchors, safe screen bounds, and HUD avoidance.

Add one signal:

```gdscript
signal offscreen_indicator_pressed(actor_id: StringName)
```

When a bubble from `EmoteDirector` is urgent and its actor is outside the camera view, render a clickable screen-edge Offscreen Indicator. Eligible bubbles are:

- persistent Escape;
- persistent Investigation;
- the 2.5-real-second danger reaction transient.

Use the bubble icon and silhouette. Do not show a numeric value or hidden cause. Give the control an accessible label such as `Focus June: escaping`.

Clamp the indicator to the usable scene edge above the Bottom HUD. Avoid the Hover Summary, Context Menu, Patron Info area, and open modal. Keep one indicator for one actor.

Connect the signal in `perception_greybox.gd`. Start a short camera focus move toward the actor. Manual pan, zoom, or another indicator press must cancel and replace the move immediately. Do not add bounce or overshoot.

The existing `EmoteDirector` already gives danger reactions a 2.5-real-second duration and freezes them during pause. Reuse that behavior; do not add another timer.

## Layout contract

Target the project viewport, `1280 × 720`.

The bottom composition is:

```text
[Selected Cultist] [Night Clock and speed] [Inspected Patron or empty] [Utilities]
```

Keep the approved proportions from the visual reference. Do not apply the rejected compressed four-column layout.

### Bottom HUD

- Root it to the bottom edge and stretch it across the viewport.
- Use the existing wood texture for the strong outer frame.
- Use `#367055` as the main folio surface.
- Use cream paper for the Cultist and Patron information panels.
- Use lighter internal framing than the outer frame.
- Keep the first three zones at one height.
- Bottom-align the Settings and Developer buttons.
- Use the built-in Godot pressed style to make active controls look physically inset.
- Use no ordinary button bounce.

Suggested palette from the approved mockup:

- Vintage green: `#367055`
- Dark folio: `#153727`
- Cream paper: `#EAD8A8`
- Paper shade: `#BFA775`
- Wood: `#744522`
- Dark wood: `#4D2D18`
- Ink: `#352416`
- Brass: `#A8793E`
- Danger: `#A14C3E`

Use `assets/environment/prototype_visual/Textures/wood_finished03.jpg` for the wood frame in the first pass. Do not alter the source texture.

### Selected Cultist zone

- Keep the portrait on the left.
- Put the Cultist name directly below the portrait.
- Show the current activity to the right.
- When a Patron is inspected, show the approved display status in this panel. Internal state remains `inspected_patron_id`.
- Use the existing character texture and palette tint as temporary portrait art.

### Action Queue

- Keep the complete Action Queue visible above the left side of the Bottom HUD whenever a Cultist is selected, including when the queue is empty.
- Render four square Action Tile slots: one active slot and up to three pending slots.
- Put the active Action first.
- Use one icon per Action and a hover summary with Action name and target.
- Give the active tile a thick bottom-up progress fill when a stable ratio exists.
- Use no horizontal drop shadow on the Action Tiles.
- Put the cancel/remove control in a small corner affordance. Disable active cancellation after the Commitment Point.
- An empty slot stays quiet and has no fake icon.

Map command identifiers to icon assets in one table in `bottom_hud.gd`. Include a neutral fallback icon so an unknown future Action does not break the HUD.

### Night zone

- Keep the analog Night Clock large and make all twelve numerals readable.
- Draw the face and hands in a custom `Control._draw()` implementation, or use twelve fixed labels inside one clock control. Do not use twelve nodes outside the clock module.
- Label the thick horizontal progress bar `Night`.
- Place the progress bar beside the clock.
- Center the speed row below the clock and progress bar.
- The selected speed must look physically depressed, not only green.
- Use buttons `1`, `2`, and `3` as visible key hints for `1x`, `2x`, and `4x`. Use a Pause icon for Space.
- Hovering the clock must show current clock time, Closing time, and Night time remaining.

There is a current document conflict: `CONTEXT.md` defines the Night Clock as `8:00 PM` to `2:00 AM`, while `GameSession._clock_label()` and the older GDD show `6:59 PM` to about `7:17 PM`. For this work, treat `CONTEXT.md` as the current source of truth. Change only the presentation mapping from simulated Night progress to clock-face time; do not change phase boundaries or gameplay durations.

### Inspected Patron zone

- Use one portrait control for both the empty and selected states. Swap its content; do not build two layouts. This guarantees that the empty portrait and the actual Patron portrait have the same position and size.
- Put the Patron name directly below the selected portrait.
- In the empty state, put `No patron selected` directly below the same portrait slot.
- Keep the empty portrait recognizable but quieter than selected content.
- Show only Observable Status and identified Patron Profile data allowed by `patron_view()`.
- Use qualitative progress fills or labeled bands. Do not show exact hidden values.
- A close icon clears the Inspected Patron without changing the Selected Cultist.

### Utility controls

- Put Settings above Developer tools, with both controls anchored to the panel bottom.
- Open each menu as an opaque popup anchored to its source button.
- Close the popup on outside click or Escape.
- Move all scenario buttons into the Developer menu.
- Move `+1s`, `+5s`, Debug, Emote Text, and UI Scale into Settings or Developer as appropriate.
- Do not keep the permanent top control rows.

Developer menu contents:

- all existing `SCENARIOS` entries;
- `+1s` and `+5s` time steps;
- Debug visibility;
- Restart current scenario.

Settings menu contents:

- Emote text labels;
- UI scale steps `75%`, `100%`, `125%`, `150%`.

Use `ConfigFile` at `user://settings.cfg` for these two settings. Do not add a general settings manager.

## Input and time behavior

Add named Input Map actions in `project.godot`:

- `simulation_speed_1` → key `1`
- `simulation_speed_2` → key `2`
- `simulation_speed_4` → key `3`
- `simulation_toggle_pause` → Space
- `open_pause_menu` → Escape

Use `GameSession.set_time_scale()` as the only simulation-speed authority.

Remove the presentation script's fixed `PLAY_SCALE` behavior. In `_process(delta)`, call `_session.advance(delta)` while the Night is running; `GameSession` applies the selected time scale internally. Set every navigable actor's simulation scale from `snapshot()["time_scale"]`.

Keep `last_nonzero_scale` in the presentation adapter:

- Space at a nonzero scale pauses to `0x`.
- Space at `0x` resumes the last accepted nonzero scale.
- Pressing `1`, `2`, or `3` selects `1x`, `2x`, or `4x` and resumes play.
- If Escape forces `1x`, the HUD must update from the snapshot and show `1x` as selected.
- If `set_time_scale()` rejects a faster speed during Escape, leave the HUD on the accepted snapshot state and show short visible feedback.

Escape key priority:

1. Close an open Context Menu.
2. Close an open Settings or Developer popup.
3. Otherwise open or close the Pause Menu.

Manual camera input remains available when the Night is paused.

## Pause Menu and Outcome Modal

### Pause Menu

Opening the Pause Menu sets the simulation scale to `0x` and remembers the prior nonzero scale. It contains:

- Resume
- Restart
- Settings
- Quit

Resume restores the remembered nonzero scale. Restart uses `get_tree().reload_current_scene()` so all Night state, queues, signals, timers, actors, and reservations are rebuilt. Runtime settings persist through `user://settings.cfg`.

### Outcome Modal

Show a blocking modal when `state["results"]["visible"]` becomes true.

Use these titles:

- `Success`
- `Operation Failed`
- `Exposed`

Show the known cause, plus Capture quota progress as a thick progress bar with an accessible value. Every Outcome Modal has:

- Restart
- Quit

Do not allow Space or speed keys to dismiss or advance the Night while an Outcome Modal is open.

## Integration steps

1. **Add the static HUD scene and theme.** Build the four approved zones, Action Tile strip, menus, Pause Menu, and Outcome Modal with sample view data. Confirm the Green Folio proportions at `1280 × 720` before connecting gameplay.
2. **Mount BottomHud in the main scene.** Instantiate it from `perception_greybox.gd`, connect its one intent signal, and render a sanitized view from existing snapshots. Keep the old HUD code present but disabled until state parity is complete.
3. **Replace time controls.** Add Input Map actions, remove fixed `PLAY_SCALE`, route all speed changes through `GameSession.set_time_scale()`, and synchronize actor movement from the accepted snapshot scale.
4. **Replace Patron and Cultist panels.** Route left-click inspection and Cultist selection into the new view. Verify the empty and selected Patron portrait use the same control and rect.
5. **Replace the Action Queue panel.** Add active cancellation to `CultistCommandSystem`, add presentation progress, and render four Action Tiles even when the queue is empty.
6. **Move developer controls.** Put the existing scenario and debug actions in anchored utility menus. Remove the permanent top rows and large debug panel only after every old action is reachable from a popup.
7. **Add Pause and outcomes.** Connect Escape priority, Pause Menu actions, clean scene reload, and the three Outcome Modal states.
8. **Add Offscreen Indicators.** Deepen `EmoteOverlay`, connect camera focus, and verify manual input interrupts camera movement.
9. **Remove the disabled old HUD.** Delete `_build_hud()` branches and fields that only served the old top controls. Keep Hover Summary and Context Menu behavior.
10. **Run verification and capture approval frames.** Do not broaden the restyle to other slices in this change.

## Automated verification

Add `tests/presentation/test_bottom_hud.gd`. Test behavior through the `BottomHud` interface, not child-node implementation details.

Cover:

- selected Cultist view renders four Action Tile slots;
- empty Action Queue remains visible;
- selected and empty Inspected Patron states reuse one portrait control;
- names render below both Cultist and Patron portraits;
- `1`, `2`, and `3` intents map to `1x`, `2x`, and `4x`;
- Space pauses and resumes the last nonzero speed;
- active and pending cancel intents include stable Action identifiers;
- Settings and Developer popups are mutually exclusive;
- Escape priority closes transient UI before opening the Pause Menu;
- Outcome Modal blocks time-control intents;
- Restart and Quit intents exist for all three outcomes.

Extend `tests/actions/test_cultist_command_system.gd` for:

- active cancellation before Commitment;
- rejection after Commitment;
- reservation release after cancellation;
- next pending Action activation after cancellation;
- `cancellable` in the normal snapshot without hidden state.

Extend the Emote Overlay presentation checks for:

- no Offscreen Indicator for an onscreen actor;
- one indicator for an offscreen urgent actor;
- no indicator for a nonurgent ordinary bubble;
- indicator press emits the actor identifier;
- HUD and modal rectangles remain reserved.

Run:

```sh
tools/test_headless.sh
tools/ticket16_presentation/run_review.sh
```

Do not add pixel-perfect automated layout tests. Use review captures for layout and keep automated tests at module interfaces.

## Manual acceptance checklist

At `1280 × 720`:

- No permanent control row remains at the top.
- The Bottom HUD matches the approved Green Folio proportions and palette.
- The Action Queue floats above the left HUD and stays visible for a Selected Cultist.
- Action Tiles are square and have no horizontal shadow.
- Vera, June, and other HUD names sit below their portraits.
- The empty Patron portrait is exactly where the selected portrait appears.
- Night and Patron progress fills are thick enough to read at a glance.
- The analog clock is the time-zone focal point and all twelve numerals are readable.
- Hovering the clock shows current time, Closing, and time remaining.
- `1`, `2`, `3`, and Space control speed and pause.
- The active speed looks pressed without relying on color alone.
- Settings and Developer menus open from and remain anchored to their buttons.
- Escape opens the Pause Menu after transient UI closes.
- Success, Operation Failed, and Exposed each show Restart and Quit.
- An urgent offscreen actor gets an edge indicator; pressing it focuses the camera.
- Manual camera input interrupts automatic focus movement.
- Hidden Patron values never appear in normal play.

Also review at `1920 × 1080` and `1024 × 576`. The HUD may scale, but its zones must not overlap, clip, or change order.

## Completion condition

The change is complete when the current main scene has feature parity with the old controls, the new Bottom HUD passes the interface tests, the lean suite remains green, and approval captures show every required state without using the rejected broad redesign.
