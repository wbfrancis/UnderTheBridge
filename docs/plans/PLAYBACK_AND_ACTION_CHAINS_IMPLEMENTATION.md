# Playback and Action Chains implementation plan

## Purpose

Fix the Green Folio playback controls and replace hidden Patron-approach movement with visible, dependent Action Chains.

This plan is an implementation handoff. It assumes no model-specific tools or behavior. Follow the repository instructions in `AGENTS.md`, preserve unrelated worktree changes, and use the project terms in `CONTEXT.md`.

Do not redesign the approved Green Folio HUD. Make only the behavior and queue changes in this plan.

## Source of truth

The settled behavior is:

### Playback

- A new interactive Night starts at `1x`.
- Space and the Bottom HUD button toggle **Plain Pause**.
- Plain Pause keeps the selected `1x`, `2x`, or `4x` button visibly selected.
- The playback button shows Pause while running and Play while paused. Its icon shows the action that a press will perform.
- Pressing a speed button selects that speed and resumes immediately.
- Pressing the already selected speed while running is a no-op.
- Plain Pause leaves camera control, inspection, and command entry available.
- The Escape **Pause Menu** blocks gameplay input.
- Space and speed shortcuts do nothing while the Pause Menu is open.
- Escape closes the Pause Menu and restores the playback state that existed before the menu opened.
- The Resume menu button always starts the Night at the selected Simulation Speed.
- An active Patron Escape forces the selected speed to `1x` and disables `2x` and `4x`.
- Plain Pause and intercept commands remain available during Escape.
- Outcome Modals continue to block every playback control.

### Action Queue and Action Chains

- One Cultist has one ordered Action Queue with one active Action and any number of pending Actions.
- No command is rejected because the Action Queue is large.
- A normal command cancels unfinished work and replaces pending work.
- If the active Action passed its Commitment Point, it finishes before the replacement starts.
- Shift+command appends without clearing existing work.
- Every Patron command that requires proximity uses a visible **Generated Move Action** when the Cultist is not adjacent.
- The Generated Move and requested Patron Action form one **Action Chain**.
- A Generated Move tracks the Patron's current valid Approach Position.
- If the Cultist is already adjacent when the Patron Action can start, no Generated Move appears.
- Cancelling or removing any unfinished Action in a chain removes every unfinished Action in that chain.
- Failure removes every unfinished Action in that chain, reports one clear failure, and starts the next unrelated Action.
- Completed gameplay effects are never undone.
- V1 creates Action Chains only for automatic prerequisites. Do not add manual chain authoring.
- The Action Tile strip grows to the right, then scrolls horizontally. The active Action remains pinned at the left.
- A small connector between adjacent tiles shows that they belong to one Action Chain.

## Current contradictions

The current implementation conflicts with the settled behavior in these places:

| Area | Current behavior | Required behavior |
|---|---|---|
| HUD speed state | Paused state clears all speed selections | Keep the selected speed visibly selected |
| Playback button | A stateful Pause toggle always shows the Pause icon | Stateless command button; Pause while running, Play while paused |
| Speed controls | Stateful toggle buttons can unpress before the authoritative render | Command buttons render only accepted state |
| Playback state | `_last_nonzero_scale` and menu state live in the large scene adapter | One playback module owns all transitions |
| Interactive scenario start | `_set_scenario()` starts ordinary play at `0x` | Start at `1x` |
| Pause Menu dismissal | Escape and Resume use the same restore path | Escape restores prior state; Resume starts selected speed |
| Escape speed lock | Faster speeds are rejected only after a press | Expose the lock and disable `2x` and `4x` |
| Queue capacity | `CultistActionQueue.MAX_PENDING_ACTIONS == 3` | Unlimited pending Actions |
| Queue HUD | Four fixed tile controls | Dynamic, horizontally scrollable tiles |
| Patron movement | Patron commands hide movement in an `approaching` stage | Visible Generated Move prerequisite when needed |
| Dependencies | Queue entries have no chain identity | Stable Action Chain identity and cascade rules |
| Cancellation | Removes one Action | Removes all unfinished Actions in its chain |

`docs/adr/0002-unify-the-cultist-command-seam.md`, `docs/PROTOTYPE_GDD.md`, `docs/TECHNICAL_DESIGN.md`, and the old Green Folio plan still describe the four-Action limit or hidden approach. Update or supersede those statements as described below.

## Module design

### 1. Add a deep NightPlayback module

Add:

- `scripts/presentation/night_playback.gd`
- `tests/presentation/test_night_playback.gd`

`NightPlayback` owns the selected Simulation Speed, Plain Pause transitions, Pause Menu return state, Escape speed-lock synchronization, and visible playback feedback. `GameSession` remains the only authority that accepts or rejects a time scale.

Use this small interface:

```gdscript
class_name NightPlayback
extends RefCounted

func reset(session, initial_speed: float = 1.0) -> void
func submit(kind: StringName, payload: Dictionary = {}) -> Dictionary
func synchronize() -> Dictionary
func snapshot() -> Dictionary
```

Supported `submit` kinds:

- `select_speed` with `{value: 1.0 | 2.0 | 4.0}`
- `toggle_plain_pause`
- `open_pause_menu`
- `dismiss_pause_menu`
- `resume_from_pause_menu`

The returned dictionary must say whether the request was accepted and include a display-ready reason when it was not. Do not make callers interpret a bare Boolean.

The normal snapshot must contain only playback presentation state:

```gdscript
{
  selected_speed: 1.0 | 2.0 | 4.0,
  time_scale: 0.0 | 1.0 | 2.0 | 4.0,
  plain_paused: bool,
  pause_menu_open: bool,
  speed_enabled: {1.0: bool, 2.0: bool, 4.0: bool},
  speed_lock_reason: StringName,
  feedback: String,
  feedback_serial: int,
}
```

Rules inside the module:

1. `selected_speed` is independent from `GameSession.time_scale` while Plain Pause is active.
2. `select_speed` updates the selected speed only after `GameSession.set_time_scale()` accepts it.
3. Selecting the active running speed returns an accepted no-op and causes no visual toggle.
4. `toggle_plain_pause` requests `0x` while running and requests `selected_speed` while paused.
5. `open_pause_menu` records whether playback was running or in Plain Pause, then requests `0x` without changing `selected_speed`.
6. `dismiss_pause_menu` restores the recorded pre-menu state.
7. `resume_from_pause_menu` always requests `selected_speed`.
8. `synchronize` reads authoritative session state after simulation changes. If Escape forced `1x`, it changes `selected_speed` to `1x`.
9. A rejected speed leaves both the selected speed and HUD state on the accepted values.
10. The module owns repeated-feedback serials so the same rejection can appear more than once.

Do not create an abstract playback interface or fake adapter. Test this module against a real `GameSession`; only one gameplay authority exists.

### 2. Expose the Escape speed lock from GameSession

Extend the player-readable `GameSession.snapshot()` with:

```gdscript
time_control = {
  available_scales: [0.0, 1.0, 2.0, 4.0],
  lock_reason: &"",
}
```

During active Escape, return:

```gdscript
time_control = {
  available_scales: [0.0, 1.0],
  lock_reason: &"active_escape",
}
```

This is player-readable state because Escape is observable. Do not expose the escaping Patron's hidden values through this field.

Keep `GameSession.set_time_scale()` as the final authority. The snapshot lets the HUD disable impossible controls before a click; the authority still rejects invalid keyboard or stale requests.

### 3. Keep BottomHud presentational

Change the `night` section of the Bottom HUD view to:

```gdscript
night = {
  clock_label,
  clock_minutes,
  closing_label,
  remaining_label,
  progress_ratio,
  time_scale,
  selected_speed,
  plain_paused,
  speed_enabled,
  speed_lock_reason,
  phase,
}
```

Remove `last_nonzero_scale` and the `BottomHud.resume_scale()` helper. Playback transitions belong in `NightPlayback`.

The Pause and speed controls must not use local toggle state as command state:

- Make the playback button a normal command button, not `toggle_mode`.
- Show `pause.svg` and “Pause the Night (Space)” while running.
- Show `play.svg` and “Resume the Night (Space)” during Plain Pause.
- Make speed buttons normal command buttons.
- Render the selected speed with the pressed StyleBox, even while paused.
- Disable `2x` and `4x` from `speed_enabled` during Escape.
- Give disabled buttons hover help such as `Escape limits the Night to 1x`.
- Do not rely on color alone for selection.

Add the new HUD intent `dismiss_pause_menu`. Escape from an open Pause Menu emits it. The Resume button continues to emit `resume_night`, which the adapter maps to `resume_from_pause_menu`.

Keep speed and Space intents blocked while the Pause Menu or Outcome Modal is open. Permit `dismiss_pause_menu` and `resume_night` through the Pause Menu.

### 4. Make CultistActionQueue unbounded and chain-aware

Remove:

- `MAX_PENDING_ACTIONS`
- the `queue_full` rejection path
- tests and documentation that assert a four-Action limit

The queue must never reject an otherwise valid Action because of its length.

Add stable chain metadata to queued Actions:

```gdscript
chain_id: int          # -1 for a standalone Action
chain_index: int       # zero-based inside the chain
chain_size: int
generated: bool
```

Keep this metadata serializable. Do not store Nodes, Callables, or navigation agents.

Deepen the queue interface around complete player operations. Exact method names can follow repository style, but the interface must support these operations without callers editing arrays:

```gdscript
func append_chain(action_specs: Array[Dictionary]) -> Dictionary
func replace_with_chain(action_specs: Array[Dictionary]) -> Dictionary
func insert_prerequisite_for_active(action_spec: Dictionary) -> Dictionary
func cancel_chain(action_id: int) -> Dictionary
func fail_active_chain(reason: StringName) -> Dictionary
```

Required behavior:

- `append_chain` adds all links in order and returns their stable identifiers.
- `replace_with_chain` clears pending work and cancels an uncommitted active Action. If the active Action is committed, it remains active and the replacement chain becomes the new pending tail.
- `insert_prerequisite_for_active` moves the current active Action behind a new Generated Move while preserving one chain identity.
- `cancel_chain` removes every unfinished Action with the same `chain_id`.
- `fail_active_chain` records one failure, removes unfinished dependent links, and activates the next unrelated Action.
- Standalone Action cancellation keeps its current behavior.
- Completed effects and completed chain links never return to the queue.

Return removed Action snapshots from cascade operations. `CultistCommandSystem` needs them to record events and release a reservation once without re-reading private queue state.

### 5. Extend CultistCommandSystem, not the scene, with chain policy

`CultistCommandSystem` remains the single command seam from ADR 0002. It owns:

- which commands require proximity;
- when a Generated Move becomes necessary;
- Action Chain creation and identity;
- cancellation and failure propagation;
- reservation transfer across chain links;
- target revalidation and gameplay execution.

The scene adapter owns only geometry facts:

- the Cultist's current world position;
- the Patron's current valid Approach Position;
- whether the actor reached that position within the existing navigation tolerance.

Add `requires_proximity` to command catalog entries. Set it for every current Patron command because all current Patron commands use the hidden approach stage. Do not add it to floor commands or smart-object commands.

Use an internal command identifier such as `generated_move`. It must:

- render with the existing Move icon and the label `Move`;
- target the Patron, not a fixed floor point;
- never appear as a Context Menu option;
- reserve the Patron Approach Position when it becomes active;
- track the live Patron Approach Position through the scene adapter;
- have no gameplay effect at completion.

Keep the public `issue(...)` interface close to its current form. Add one request-only geometry fact:

```gdscript
func issue(
  cultist_id: StringName,
  command: StringName,
  target: Dictionary,
  append: bool,
  context: Dictionary = {} # {is_adjacent: bool}
) -> Dictionary
```

`is_adjacent` is a geometry observation. The adapter computes it from the same live Approach Position and arrival tolerance used by navigation. The command module decides what that fact means.

Issue behavior:

- A non-proximity command creates one standalone Action.
- A proximity command issued while not adjacent creates `Generated Move -> requested Action` as one chain.
- A proximity command issued while adjacent creates only the requested Action.
- Return `action_id` for the requested Action, plus `chain_id` and `generated_action_ids`. Do not make callers guess which identifier belongs to player intent.
- Normal issue uses `replace_with_chain`; Shift issue uses `append_chain`.

Recheck proximity when a pending Patron Action becomes active. This handles a Patron who moved while earlier queued work ran:

- If still adjacent, reserve the Approach Position and execute the Action.
- If no longer adjacent and the chain has no unfinished Generated Move, insert a Generated Move before the active Action.
- Do not loop silently. At most one Generated Move for the same requested Action can be unfinished at a time.
- If the Patron leaves play or becomes invalid, fail the chain once and continue to the next unrelated Action.

Extend `active_request()` with a mode:

```gdscript
{
  action_id,
  command,
  mode: &"navigate" | &"check_proximity",
  target_kind,
  target_id,
  position,
}
```

- Generated Move and existing smart-object/floor movement use `navigate`.
- A Patron Action whose prerequisites finished uses `check_proximity`.
- The adapter reports the current proximity result through a small command-system method. The command system either commits the Action or inserts the missing prerequisite.

Do not let the adapter create chain entries or remove dependent Actions.

### 6. Preserve one reservation across a Patron Action Chain

The Patron Approach Position is reserved when the Generated Move becomes active, not when the chain is pending.

Keep that reservation through the dependent Patron Action. Do not release and reacquire it between links because another Cultist could steal the position in that gap.

Release the reservation exactly once when:

- the chain completes;
- the chain is cancelled;
- the chain fails;
- the Patron becomes invalid;
- the Night resets or ends.

If the Cultist was already adjacent and no Generated Move exists, reserve the position when the Patron Action becomes active.

Update ADR 0002's rule only by supersession: pending chains still reserve nothing, so the original reason against early reservation remains valid.

### 7. Build a dynamic Action Tile strip

Replace `TILE_COUNT` and the fixed `_tile_slots` array in `BottomHud`.

Use this layout:

```text
[active tile, fixed] [horizontally scrolling pending tiles ---------------->]
```

Behavior:

- Keep a four-tile minimum footprint while the Selected Cultist queue is empty.
- Keep the active tile pinned at the left.
- Create one square tile for every pending Action.
- Let the strip grow right until it reaches the safe screen width, then scroll pending tiles horizontally.
- Reveal a newly Shift-appended tail Action.
- Preserve square size and the existing no-horizontal-shadow treatment.
- Keep cancellation controls bound to stable `action_id` values, not mutable tile indexes.
- Render a subtle connector only when adjacent Action views share a nonnegative `chain_id`.
- Keep hover text and progress behavior.
- Show Generated Move as `Move` with the current Move icon.

Extend display-ready Action views with:

```gdscript
{
  id,
  command,
  icon,
  label,
  target_label,
  active,
  cancellable,
  progress_ratio,
  chain_id,
  chain_index,
  chain_size,
  generated,
}
```

Cancellation from any linked tile submits its stable Action identifier. `CultistCommandSystem` applies the cascade.

### 8. Thin the scene adapter

In `scripts/prototypes/perception_greybox.gd`:

- Add one `NightPlayback` instance.
- Route HUD and keyboard playback intents through `NightPlayback.submit()`.
- Call `NightPlayback.synchronize()` after session advancement and Escape state changes.
- Build the HUD `night` view from `NightPlayback.snapshot()` plus clock progress.
- Remove `_last_nonzero_scale` and local transition logic.
- Split Pause Menu dismissal from Resume.
- Start ordinary interactive scenarios at `1x`.
- Keep automated captures and validation flags authoritative for their requested speed.
- Compute `is_adjacent` from the live Patron Approach Position and the current navigation arrival tolerance before `CultistCommandSystem.issue()`.
- Drive `active_request().mode` without creating or editing Action Chains.

Plain Pause must continue through the existing nonblocking input route. The Pause Menu and Outcome Modal remain blocking through `BottomHud.is_blocking()`.

## Documentation changes

Create `docs/adr/0003-use-visible-action-chains.md` during implementation. It must supersede only these parts of ADR 0002:

- the four-Action limit;
- the assumption that every contextual command hides its approach inside one Action.

Keep ADR 0002's decisions for one command seam, serializable targets, one queue authority, and activation-time reservations.

Update:

- `docs/PROTOTYPE_GDD.md`: unlimited Action Queue, Action Chains, Generated Move, dynamic tile strip, and final playback rules.
- `docs/TECHNICAL_DESIGN.md`: `NightPlayback`, chain-aware command seam, proximity geometry fact, reservation transfer, and new test seams.
- `docs/slices/SERVICE_ACTION_QUEUE_SLICE.md`: remove the four-Action authority claim if the slice still exercises the shared queue.
- `docs/plans/GREEN_FOLIO_HUD_IMPLEMENTATION.md`: add a short status note that this plan supersedes its four-tile and old pause-state details. Do not rewrite the historical plan.

Do not add implementation details to `CONTEXT.md`. The glossary changes are already present in the worktree.

## Implementation sequence

1. **Protect the handoff state.** Check `git status`. Preserve the unrelated generated validation changes. Do not reset or stage them.
2. **Add failing playback tests.** Cover the complete transition table through `NightPlayback`, then implement the module and GameSession lock view.
3. **Replace HUD toggle behavior.** Make the controls render authoritative state only. Add Play/Pause icon switching and disabled Escape speeds.
4. **Integrate playback in the live adapter.** Remove the split state and start interactive Nights at `1x`.
5. **Add failing unbounded-queue tests.** Remove the capacity limit and queue-full path only after the tests express replacement and append behavior.
6. **Add Action Chain primitives.** Implement stable metadata, chain insertion, cascade cancellation, cascade failure, and unrelated progression in `CultistActionQueue`.
7. **Add Generated Move policy.** Extend the command catalog and command-system issue/activation paths. Preserve reservation ownership through the chain.
8. **Integrate live proximity.** Supply geometry facts and track moving Patron Approach Positions in the scene adapter.
9. **Replace the fixed tile strip.** Add dynamic pending tiles, scrolling, stable-ID cancellation, and connectors.
10. **Update domain-facing documents.** Add ADR 0003 and update the GDD, technical design, slice note, and old-plan status.
11. **Run headless verification.** Fix all regressions before visual review.
12. **Run the interactive test scene.** Exercise rapid playback input and long Action Queues by hand.
13. **Capture approval evidence.** Update only relevant Green Folio screenshots and add focused playback/chain frames.
14. **Commit only scoped files.** Leave unrelated validation artifacts uncommitted.

## Automated tests

### NightPlayback tests

Cover this transition table:

| Start | Input | Result |
|---|---|---|
| Running `1x` | Space/HUD toggle | Plain Pause, selected `1x` |
| Plain Pause, selected `1x` | Space/HUD toggle | Running `1x` |
| Running `2x` | Space | Plain Pause, selected `2x` |
| Plain Pause, selected `2x` | select `4x` | Running `4x`, selected `4x` |
| Running `2x` | select `2x` | Accepted no-op |
| Running | open Pause Menu | Menu open, `0x`, prior state recorded |
| Plain Pause | open then dismiss menu | Plain Pause restored |
| Running `2x` | open then dismiss menu | Running `2x` restored |
| Plain Pause, selected `2x` | open then Resume | Running `2x` |
| Escape active | synchronize | selected `1x`; `2x`/`4x` disabled |
| Escape active at `1x` | Space | Plain Pause, selected `1x` |
| Outcome visible | any time request | rejected and unchanged |

Also cover rapid repeated Space presses and repeated selected-speed presses. The final state must be deterministic with no local control drift.

### CultistActionQueue tests

Add or change tests for:

- at least 100 appended pending Actions with no capacity rejection;
- FIFO order across the full queue;
- normal replacement of an uncommitted active Action;
- normal replacement behind a committed active Action;
- Shift append after a committed Action;
- stable Action and chain identifiers;
- cancelling any chain member removes every unfinished member;
- failing the active chain removes dependents and starts the next unrelated Action;
- completed links stay completed and are never undone;
- reset clears all chains and identifiers safely.

Remove tests that expect the fifth Action to fail.

### CultistCommandSystem tests

Cover:

- every current Patron command is marked proximity-dependent;
- nonadjacent Talk creates visible `Move -> Talk` with one chain identity;
- nonadjacent Offer Cigarette creates visible `Move -> Offer Cigarette`;
- at least one other Patron command proves the catalog-wide rule;
- adjacent Patron command creates no Generated Move;
- Shift appends a complete chain after unrelated work;
- a Patron who moves before a pending Action starts causes a Generated Move insertion;
- Generated Move tracks the live target until arrival;
- Generated Move and dependent Action share one reservation without a release gap;
- cancellation from either tile removes all unfinished links and releases the reservation;
- navigation failure cancels dependent links and starts the next unrelated Action;
- Patron departure or Capture fails the chain once;
- two Cultists still produce one approach owner and one visible rejection;
- snapshots expose only display chain metadata and no hidden Patron values;
- no `queue_full` reason remains in normal behavior.

### BottomHud tests

Replace the fixed-four assertions with:

- a selected Cultist with an empty queue shows the four-slot minimum footprint;
- a queue with more than four Actions renders every Action;
- the active tile remains pinned while pending tiles scroll;
- stable Action identifiers drive cancellation after scrolling;
- chain connectors appear only between adjacent members of the same chain;
- Generated Move uses the Move icon and label;
- paused state keeps the selected speed visually pressed;
- playback icon is Pause while running and Play while paused;
- pressing the selected speed emits a selection intent but never locally unpresses it;
- Escape lock disables `2x` and `4x` with help text;
- Pause Menu blocks Space and speeds;
- Escape emits `dismiss_pause_menu`, while Resume emits `resume_night`.

### Integration tests

Add a focused integration test or deterministic review mode that crosses the real seams:

```text
keyboard or HUD intent
  -> BottomHud intent
  -> NightPlayback
  -> GameSession
  -> NightPlayback snapshot
  -> BottomHud render
```

Cover Space, speed selection, selected-speed no-op, Escape menu restore, Escape menu Resume, and Escape speed lock. Existing isolated HUD and GameSession tests do not prove this route.

Also extend the command integration review to prove:

```text
nonadjacent Patron command
  -> Generated Move tile
  -> live navigation to moving Approach Position
  -> requested Patron Action
  -> chain completion and reservation release
```

## Manual and visual acceptance

Run the interactive scene:

```text
res://scenes/prototypes/ticket16_presentation_review.tscn
```

Check playback:

1. Start a Night and confirm `1x` is running and visibly selected.
2. Press Space rapidly several times. One press produces one transition and no button flicker remains.
3. Pause at `2x`; confirm `2x` stays selected and the icon becomes Play.
4. Press `4x` while paused; confirm the Night resumes at `4x`.
5. Press the selected speed repeatedly; confirm no state changes.
6. Open the Pause Menu from running, dismiss with Escape, and confirm running restores.
7. Open it from Plain Pause, dismiss with Escape, and confirm Plain Pause restores.
8. Use Resume from a menu opened during Plain Pause; confirm the selected speed starts.
9. Trigger Patron Escape. Confirm `1x` is selected, `2x` and `4x` are disabled, and Space still pauses.
10. Confirm camera control, inspection, and commands work in Plain Pause but not through the Pause Menu.

Check Action Chains:

1. Select a distant Patron command and confirm `Move -> requested Action` appears.
2. Shift-append several Patron commands until more than four tiles exist.
3. Confirm the strip scrolls, the active tile remains fixed, and no command is rejected for length.
4. Confirm linked tiles use the subtle connector.
5. Cancel the Generated Move and confirm its dependent Action disappears.
6. Cancel the dependent pending tile and confirm the unfinished Generated Move also disappears.
7. Cause navigation failure and confirm the next unrelated Action starts.
8. Queue a Patron Action while adjacent, then let the Patron move before activation. Confirm the system inserts a Generated Move when the Action reaches the head.
9. Confirm a moving Patron updates the Generated Move destination.
10. Confirm two Cultists cannot own the same Patron Approach Position.

Add or update Green Folio approval frames for:

- running `1x`;
- Plain Pause with `2x` still selected and the Play icon visible;
- Escape speed lock;
- a four-slot empty queue;
- a long scrolling queue;
- a visible `Move -> Talk` chain;
- a chain followed by an unrelated Action;
- Pause Menu opened from Plain Pause.

Review at `1280x720`, `1024x576`, and `1920x1080`. Do not accept clipped tiles, inaccessible cancellation controls, or overlap with the Bottom HUD and Offscreen Indicators.

## Required commands

Run the repository's existing checks:

```bash
tools/test_headless.sh
tools/green_folio_hud/run_review.sh
```

Run any command-system review script that the implementation changes. Keep Bash and PowerShell review scripts in parity when their behavior changes.

Also run:

```bash
git diff --check
```

The headless suite, visual review, and interactive checks must all pass before commit.

## Out of scope

Do not add:

- manual Action Chain authoring;
- Action reordering by drag;
- a maximum queue size;
- a second movement queue;
- hidden queue overflow rejection;
- a new camera model;
- changes to unrelated slice UIs;
- new Patron gameplay effects;
- a redesign of the Green Folio composition.

## Completion checklist

- [ ] `NightPlayback` owns every playback transition behind its small interface.
- [ ] `GameSession` remains the Simulation Speed authority and exposes the Escape lock safely.
- [ ] Space and the HUD button are identical Plain Pause toggles.
- [ ] Speed selection remains visible during Plain Pause.
- [ ] Pause Menu dismissal and Resume have distinct behavior.
- [ ] Interactive Nights start at `1x`.
- [ ] Action Queue length cannot reject a command.
- [ ] Patron proximity creates visible Generated Move prerequisites only when needed.
- [ ] Generated Move and requested Action use one Action Chain identity.
- [ ] Chain cancellation and failure cascade only through unfinished dependent work.
- [ ] The next unrelated queued Action continues.
- [ ] Reservations remain correct through chain completion, cancellation, failure, and reset.
- [ ] The Action Tile strip renders unlimited entries through horizontal scrolling.
- [ ] Active Action stays pinned and chain connectors remain subtle.
- [ ] Player-facing snapshots expose no hidden Patron values.
- [ ] ADR, GDD, technical design, slice notes, and old-plan status agree with the implementation.
- [ ] Automated tests pass.
- [ ] Interactive playback and queue checks pass.
- [ ] Review images pass at all three target resolutions.
- [ ] Unrelated validation artifacts remain outside the commit.
