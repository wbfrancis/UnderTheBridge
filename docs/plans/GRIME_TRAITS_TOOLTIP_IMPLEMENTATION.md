# Implement Grime, Patron Traits, Smoking, and the Modifier Tooltip

## Objective

Implement the settled design in `docs/design/GRIME_TRAITS_TOOLTIP.md` in the current
playable presentation. Preserve the vocabulary in `CONTEXT.md` and the architecture in
ADRs 0001–0006. This plan covers gameplay, presentation, automated checks, and the final
human visual review.

The design document is authoritative for values and player-facing rules. The approved
Modifier Tooltip is stored at `docs/design/visuals/modifier-tooltip.png`. Written rules
control behavior; the image controls frame, spacing, type, colors, and hierarchy. Its
illustrative modifier combinations do not override catalog exclusions. The approved Grime treatment is
`docs/design/visuals/grime-study-v1.png`, with one correction: omit its Grime In Sight
panel and use slightly pulsing brass outlines as the only Grime Inspection signal.

## Working rules

- Start from the current dirty working tree. Inventory and preserve all existing work;
  do not reset, clean, restore, or overwrite unrelated changes.
- Keep `OrdinaryVisitSession` as gameplay authority. Expose view data through
  `GameSession`; keep `perception_greybox.gd` a scene and input adapter.
- Keep character work in `CharacterActionSystem`. Extend `CultistCommandSystem` for
  player commands, including Reason With, and the Patron planner/coordinator for
  autonomous Smoking.
- Use seeded randomness from the Night for Trait rolls, Grime source rolls, Ruined
  Bathroom rolls, and autonomous Smoking. A replay with the same seed must match.
- Treat Traits and exact Grime values as hidden domain state. Normal views expose only
  facts allowed by `Patron Profile`, `Observable Status`, `Unknown Modifier`, and Grime
  Inspection.
- Put qualitative frequencies such as “orders more often” and “low idle rate” behind
  named tuning constants. Pick conservative first-pass values,
  cover their direction with tests, and list them in the final handoff for later balance.
- Add no new Trait effects, Grime sources, alerts, separate Grime panels, threshold labels, clean-time
  numbers, or Suspicion effects.
- Use `PatronSatisfaction` and Satisfaction Modifiers from ADR 0006. Mood remains a
  derived label and no gameplay rule reads it.

## Stage 1 — Baseline and contract map

Read `CONTEXT.md`, the settled design document, ADRs 0001–0006, and the current tests.
Run `tools/test_headless.sh` and record the baseline. Map each existing service, bathroom,
Suspicion, Satisfaction, Friendship, Knock Out, Investigation, Escape, profile, Context
Menu, and HUD path to one rule in the design. Record any conflict before code changes;
the settled design wins only within this feature scope.

Inventory tests and review fixtures that encode replaced rules. In particular, inspect
`tests/simulation/test_ordinary_visit_session.gd` (whole-level drink-free decay),
`tests/simulation/test_actor_identity.gd` and `tests/fixtures/actor_seed_trace.json`
(pre-feature gameplay traces), and `tests/actions/test_cultist_command_system.gd`
(instant repeated Cigarette setup). Migrate each alongside its owning implementation
stage, with an explicit design reason and deterministic Trait setup. Review changed
trace fields individually; do not regenerate fixtures merely to accept current output.
Preserve actor-renumbering invariance and unaffected regression coverage.

Use these existing test seams: `tests/patrons/` for catalog, Satisfaction, Suspicion,
perception, and planner rules; `tests/actions/` for shared Action and command lifecycles;
`tests/simulation/` for authoritative cross-system results and view projections; and
`tests/presentation/` for actual controls and production-scene integration. New focused
files may live beside these tests. Inspect the local visual references before UI work.

Implement domain and command contracts before their presenters. Stage 3 defines chance
breakdown contracts; Stage 3A supplies Reason With's operational result. Stage 5 supplies
Clean target/timing contracts; Stage 8 supplies the final patch render/picking adapter.
Stage 9 must exercise those adapters together, not only direct simulation calls.

**Complete when:** the baseline is recorded and every settled rule has an owner, a view
boundary, and a planned test location.

## Stage 2 — Patron Trait model and deterministic assignment

Add a focused Trait catalog/model instead of embedding Trait branches throughout
`OrdinaryVisitSession`. Give each Trait a stable ID, player label, reciprocal
`incompatible_with` Trait IDs, and effect data. The model must support:

- exactly one Drink Preference: Wine Drinker, Beer Drinker, or Whiskey Drinker;
- two independent 50% rolls for up to two additional Traits, producing a 25% / 50% /
  25% distribution of one / two / three total Traits;
- all 20 catalog Traits;
- exclusion of Weak/Strong, Hollow Leg/Lightweight, Lush/Lightweight,
  Paranoid/Trusting, Nosy/Oblivious, Germaphobe/Slob, Big Tipper/Tightwad, and
  Sociable/Grouch;
- catalog checks for missing, duplicate, asymmetric, and self-referencing exclusions;
- uniform seeded selection from the complete valid loadouts for the rolled count;
- seeded, reproducible rolls at Night start using the Night seed and the Patron's
  authored `seed_key`, never actor ID or display name;
- an independently known Trait set, separate from full Patron identification;
- full Trait reveal on identification, early Non-Smoker reveal on refusal, and early
  Oblivious reveal through its Hard-Evidence confusion reaction.

Apply Trait effects at the owning calculation, not in UI projections. Use small modules
where one rule has its own clock or lifecycle, especially Reason With eligibility and
the Smoking Satisfaction effect. Keep the catalog data-driven so later balance changes
alter one definition.

Add headless tests for the count distribution contract, Drink Preference uniqueness,
every incompatibility and catalog-integrity failure, valid-loadout selection, seed replay,
full reveal, both early single-Trait reveals, and hidden effects that stay active.
Extend the actor-renumbering test to compare Trait loadouts. Test the four outcomes of
the two independent count rolls directly; do not require exact population percentages
from a small random sample. Check uniform loadout selection without relying on catalog
iteration order. Map Whiskey Drinker to the existing `liquor` drink ID; do not add a
fourth drink type.

**Complete when:** every Patron receives a valid deterministic loadout and public views
cannot infer hidden Trait names from raw fields.

## Stage 3 — Trait effects on existing systems

Wire the catalog into the current authoritative calculations:

- **Knock Out:** Weak +15 points; Strong −15 points; clamp the final chance to 5–99%.
- **Intoxication and drinking:** replace whole-level storage with hidden integer progress:
  0–5 Sober, 6–11 Tipsy, 12–17 Drunk, and 18 Max Drunk. Any completed drink adds 6,
  Hollow Leg adds 4, and Lightweight adds 9. Remove one point every 40 gameplay seconds
  while progress is above zero; later drinks do not reset the steady decay. Ideal
  Intoxication and Knock Out read the visible level. An Excess Drink counts only when
  progress was already 18.
  Hollow Leg adds 2 to a baseline Overdrink Limit roll of 1–3, with a maximum of 5;
  Lightweight subtracts 1 with a minimum of 1. Lightweight shifts Ideal Intoxication
  −1, Lush shifts it +1 and Orders more often, and Nurser makes drink completion 1.5
  times as long. Clamp discrete values at their documented bounds.
- **Drink Preference:** prefer the matching Order 80% of the time. A wrong drink pays
  base price and halves only the Satisfaction-based tip. When an Order exists, matching
  that Order controls correctness; otherwise compare the drink with Drink Preference.
- **Suspicion and Friendship:** Paranoid multiplies Suspicion gain by 1.5; Trusting
  multiplies Suspicion gain by 0.5 and Friendship gain by 1.5. Paranoid adds 20, Nosy
  adds 15, and Oblivious subtracts 25 points from the
  hearing-only Knock Out notice roll; visual witnesses still receive Hard Evidence.
  A missing Companion reaches Investigation after 60 seconds, or 30 seconds for Nosy.
- **Economy and Satisfaction:** Big Tipper adds 50 points to each tip band; Tightwad
  subtracts 50 with a zero floor; Sociable starts at +15 Satisfaction and multiplies
  Talk Satisfaction by 1.5; Grouch starts at −15 and gains no Talk Satisfaction unless
  the Satisfaction band was already Happy before the Talk reward.
- **Cleanliness:** Germaphobe and Slob effects are applied in Stage 5.
- **Smoking:** Non-Smoker effects are applied in Stage 6.

Make each shown Knock Out and Reason With percentage return a structured breakdown:
stable source ID, public label when known, signed point change, and final value. The
domain result owns the math; presentation formats it. Do not apply a Suspicion multiplier
to Hard Evidence that sets Suspicion to 100. Keep Max Drunk's current Hard Evidence
downgrade. The removed five-second Oblivious grace must leave no timer or source-tracking
path. Add focused tests for every Trait, relevant combinations, progress boundaries,
decay, clamps, and known/unknown projections.

Audit every Intoxication reader and writer, including drugged-drink collapse, helper
selection, stay-behind calculations, review setters, events, and debug views. Use one
visible-level conversion from progress; do not leave readers treating progress as a
0–3 level. Route actual drink gains through one authoritative operation without double
counting completion or collapse. Preserve existing drug timing unless the design changes
it. Update drink-duration projections as well as completion checks for Nurser.

Replace the existing 40-second missing-Companion terminal threshold with the specified
60/30-second rule, including its stimulus, flags, debug names, and fixtures. Preserve
the existing intermediate pressure events unless a settled rule changes them. Test
baseline and Nosy timing with other Suspicion Traits so gain scaling cannot accidentally
replace the specified Investigation threshold. Apply gain multipliers at all owning
gain paths, including Companion influence, without scaling recovery or direct maximum
assignments. Keep Companion influence bounded by its source's score.

**Complete when:** each Trait changes only its documented calculations and all effects
work while the Trait remains hidden.

## Stage 3A — Reason With and Oblivious reaction

Add `Reason With` as a proximity Action through `CultistCommandSystem` and the normal
Generated Move, Action Chain, reservation, cancellation, and target-revalidation paths.
It is available once a Patron reaches 95 Suspicion and remains available through 100.
Hard Evidence blocks it unless the Patron has Oblivious. Allow it during normal activity,
Investigation, shock, Escape, and Intercept.

Contact pauses the Patron for five simulated seconds. Success lowers Suspicion to 50,
clears the Hard-Evidence lock for an Oblivious Patron when applicable, cancels
Investigation or Escape, and returns the Patron to normal behavior. Failure resumes the
prior behavior. Permit one completed roll during each continuous visit to the 95–100
range; falling below 95 resets eligibility. Only the completed roll consumes the
attempt. Cancellation before the roll resumes prior behavior without consuming it or
drawing a result. Use a 60% base chance, Oblivious +20, Nosy −20, and
a 5–95% clamp.

Add a coordinator-owned hold/resume contract before wiring command execution. Preserve
the interrupted Action identity, elapsed time, destination, navigation state, deferred
work, and required reservations. The current planner rejects Escape/Investigation to
routine transitions, and normal coordinator activation clears the previous queue; a
new ordinary Talk-like state alone cannot implement this hold. Suspend the held
behavior's progression in every owning path, including the separate Investigation,
shock, Escape, and Intercept advancement paths. Keep the hold exclusive per Patron.
Do not introduce a second queue clock in the scene or let an in-flight command reject
itself because its own hold made the Patron busy.

On success, clear the applicable maximum response, Hard-Evidence lock, deferred Escape
request, and `escape_after_bathroom` state. End obsolete Intercept work and release its
reservations. Restore an active Patron through valid normal intent/seat acquisition;
Escape may already have released their seat and cancelled their Order. Do not resurrect
cancelled Orders. On failure or cancellation, restore the saved work and remaining time
without replaying entry effects. Terminal removal, target loss, and Night restart must
clear the hold and its saved work without resurrecting an actor.

During Intercept, hold the Patron continuously through handoff. Pause Intercept's
remaining time; success ends both Actions, while failure or cancellation resumes the
remaining Intercept. Support the same Cultist switching directly to Reason With and a
second Cultist performing it while the first owns Intercept. Keep one active Action per
Cultist, using saved/paused work for resumption. Replacement and cleanup must be atomic
so releasing one engagement does not briefly let the Patron escape. If prior work loses
its actor or target, revalidate it rather than restoring an invalid reservation.

When an Oblivious Patron receives Hard Evidence, replace the existing two-second shock
presentation with a confusion reaction. Add no delay. The reaction reveals Oblivious,
which makes Reason With available despite Hard Evidence and resolves its Trait modifier.
Non-Oblivious Patrons keep the immediate normal reaction and cannot be Reasoned With
after Hard Evidence.

Test availability at 94/95/99/100, Soft Suspicion and Hard Evidence, both Trait modifiers,
unknown projection, contact hold, success, failure, cancellation, one attempt per range
visit, reset below 95, Investigation, shock, Escape, Intercept, seated Trapdoor evidence,
confusion reveal, and removal of the old grace behavior.
Use real command/coordinator tests for same- and second-Cultist Intercept handoffs,
remaining-time preservation, no movement during contact, and cleanup of both queues.
After success, advance several ticks and complete another normal activity to prove the
Patron stays recovered; after failure, prove the old behavior resumes from its saved
progress. Test cancellation just before the roll, exactly one completion roll, and
contention between two Cultists. Check seated evidence success does not later trigger
the stale bathroom Escape flag. Preserve Escape's existing 1x speed restriction.

**Complete when:** Reason With uses the shared command and Action lifecycle, and every
maximum-response path follows the same eligibility and resolution rules.

## Stage 4 — Grime domain model and sources

Add a Grime store owned by the simulation. Each patch needs a stable ID, room, horizontal
center, authored surface ID/type, current clean-seconds, maximum 30 seconds, and enough
presentation data to clip its footprint to the surface. Merge new Grime into the patch at
the same stable Grime slot; patches never spread or merge by coordinate proximity.
The two-second minimum applies only on creation. Store fractional clean-seconds (a
Slob drink adds 4.5s). A positive remainder below two seconds remains a valid patch and
the next Clean uses its actual time; never round it up or discard it.

The scene supplies stable Grime slots, surface bounds, and Approach Positions. Finished
drinks use the Patron's seat or authored drinking-position slot. Normal Bathroom Visit
Grime uses one bathroom-use slot. Ruined Bathroom uses a separate blocking slot. Bladder
soiling creates a fresh patch at the Patron's current position with an event-based ID.

Create patches from the settled sources:

- completed drink: 50% chance, +3 seconds at the drinker's spot;
- Slob completed drink: 100% chance and 1.5 times size;
- completed Bathroom Visit: +4 seconds at the bathroom spot;
- 60 seconds at full Bladder: fresh +8-second patch at the Patron, then reset Bladder;
- Ruined Bathroom: one seeded 20% roll when a Max Drunk Patron starts Seated Bathroom
  Use. Success adds a separate 28-second patch, while the current visit still completes
  and adds its normal +4 seconds. The blocking patch prevents later Bathroom Visits until
  fully cleaned;
- no Cultist or Trapdoor source.

Use scene-supplied authored surface and position facts. The scene must not decide whether
Grime exists, grows, blocks the bathroom, or finishes cleaning. Add snapshot and debug
hooks sufficient for deterministic tests and review setup without exposing clean-time
numbers in normal UI.

Apply completed-drink Grime exactly once before an Overdrink Collapse can return from
the completion path and before seat cleanup removes the source slot. The current
`_finish_drink` returns before `drink_completed` on Overdrink Collapse, so subscribing
only to that event would miss this source. Test ordinary and collapsing completed
drinks, and audit drugged-drink paths for duplicate or missing completion effects.

Test every source, roll boundary, Slob multiplier, slot growth, fresh-patch IDs,
30-second cap, surface clipping contract, full-Bladder timer/reset, the single Ruined
Bathroom roll, normal and blocking bathroom patches, current-visit completion, later
visit blocking/unblocking, restart cleanup, and the absence of Trapdoor/Cultist effects.
Include creation minimum, fractional growth, and the 29s snapshot → 30s cap → 1s remainder
case, followed by a one-second Clean that removes the patch.

**Complete when:** all Grime mutations are deterministic simulation events and the
bathroom block follows the authoritative Ruined Bathroom patch.

## Stage 5 — Sighted Grime, Satisfaction pressure, and Clean Action

Extend perception through a range parameter or a dedicated method that shares the
current room-and-facing math. Sighted Grime uses the patch center, same room, at most five
horizontal meters, and the existing inclusive ±60-degree cone. It counts the whole patch
or none. Furniture does not occlude it and vertical look direction does not apply.

For each Patron, sum the clean-seconds of Sighted Grime. Start a source-scoped
Satisfaction Modifier at six seconds for a Germaphobe and 15 seconds for everyone else.
Slobs are immune. Drain about 2 Satisfaction per simulated second, doubled for
Germaphobes, and recover the same applied loss at the same rate after the condition
clears. A normal Patron's modifier stops at 25 Satisfaction; a Germaphobe's can reach 0
and cause Normal Departure. Track this source separately so recovery cannot repay
Satisfaction lost to service, Talk, or other events. Pause and Simulation Speed must
follow existing simulation-clock rules.

Define the Grime contribution against the current base and other modifiers, not a
one-time cap computed at exposure start. `PatronSatisfaction` currently decays its base
independently and clamps only the final sum to 0–100. Test sustained normal-floor
exposure while ordinary decay continues, Smoking expires or is interrupted, and service
rewards or penalties occur. Grime must cause no additional loss below its allowed floor;
it must not raise a Patron already below that floor or erase an unrelated penalty.
Recovery must repay no more than this source's applied loss. Keep that bookkeeping in
the domain, with the Satisfaction module owning composition and the Grime pressure
rule owning exposure and recovery state.

Before Clean, add a serializable Grime target contract with stable patch identity,
surface identity, validated floor Approach Position, and approach reservation. Extend
command resolution, target normalization, Generated Move, reservation transfer, target
revalidation, and navigation callbacks for it. The existing target kinds omit Grime,
normalization reconstructs approach slots, and command durations come from a static
catalog; these seams need explicit extensions. Preserve supplied validated approach
facts and reserve at activation, not while work is merely queued. Keep patch ownership
exclusive as well as the approach reservation. Dynamic soiling patches need a reachable
floor approach derived from scene geometry, without moving the patch itself.

Add `Clean` as a proximity Action for floor, table, and bar Grime. Its duration snapshots
the current patch clean time when the Action commits. Reserve the patch for one Cultist.
Route it through `CultistCommandSystem`, the normal Generated Move prerequisite, Action
Chain cancellation, target revalidation, and surface Approach Position. Completion
removes only the snapshotted amount, so Grime added during the Action remains; delete the
patch only at zero. Cancellation removes nothing. Clear a Ruined Bathroom block only
when its blocking patch reaches zero. The Action Tile can show ordinary progress;
player-facing hover text and inspection must not show seconds-to-clean.
Treat contact as the snapshot/start boundary and final removal as the irreversible
effect. Keep the Action cancellable until completion even though the snapshot is fixed.
Expose session-authoritative duration and progress through the queue's timing contract;
do not reuse a zero/static catalog duration or add a scene timer. Handle cancellation,
queue replacement, Cultist incapacity, target loss, and restart through one cleanup path.

Test center-versus-edge sight, inclusive distance/cone boundaries, cross-room exclusion,
all surface types, sums across clusters, thresholds, Germaphobe double pressure, Slob
immunity, both Satisfaction floors, source-scoped recovery, re-entry during recovery,
pause/speed, exclusive Clean reservation, snapshotted duration, concurrent growth,
cancellation, target loss, queue append/reset, and bathroom unblock.

**Complete when:** Satisfaction responds only to each Patron's Sighted Grime and Clean
uses the same command and Action lifecycle as other proximity work.

## Stage 6 — Smoking and Non-Smoker behavior

Replace the current instant Friendship-only Cigarette operation with the settled Offer
Cigarette Action result while retaining its existing +10 Friendship reward on acceptance.

Add Smoking as a real idle Action available to any character. Patron Smoking applies a
60-second source-scoped Satisfaction Modifier: 10-second fade-in to +10, 40-second hold,
then 10-second fade-out. Removing or interrupting it must remove only its own remaining
contribution. Cultist Smoking is cosmetic. Patrons may choose it at a low seeded idle
rate; Non-Smokers never choose it. Offer Cigarette is available only when the Patron can
start an idle Action and starts Smoking when accepted. A Non-Smoker refuses, loses 5
Satisfaction, reveals only Non-Smoker, gains no Friendship, and does not start Smoking.

Integrate Patron Smoking through `PatronIntentPlanner` and `PatronActionCoordinator` so
priority, interruption, debug queue control, and replay remain consistent. Add the state
to the transition table and visible activity projection. Give the presentation a simple
observable Smoking treatment that does not reveal a hidden Trait before behavior does.

Test the full Satisfaction curve at boundaries, source-scoped removal, Patron/Cultist
difference, idle eligibility and seeded selection, interruption/priority, accepted +10
Friendship, refusal, −5 Satisfaction, early reveal, and repeated offers.
Exercise the real Smoking integration to prove ordinary Satisfaction decay stops while
its positive modifier is active and resumes afterward. Check refresh never stacks the
same source, clipping near 100 does not create a later loss of base Satisfaction, and
debug cancellation/forced completion removes only Smoking's contribution. Ensure
Cultist Smoking has an executable shared-queue path and cosmetic projection, rather
than an unreachable catalog entry; do not add an unrequested player command.

**Complete when:** Smoking is a queued Action, its Satisfaction contribution is reversible
and isolated, and Non-Smoker behavior reveals exactly one Trait.

## Stage 7 — Modifier Tooltip and information policy

Use the approved mockup at `docs/design/visuals/modifier-tooltip.png`; do not approximate
or replace it silently.
Implement one reusable Modifier Tooltip presenter for shown percentages. Knock Out and
Reason With are the first consumers. Render Base with its source, one line per modifier,
and brass Total.
Known increases use green and `+`; known decreases use red and `−`. If any active
modifier comes from an unknown Trait, render a neutral grey `???` line and `???` Total.
Do not leak sign, value, spacing, icon, ordering, color, or accessible text that identifies
the hidden Trait. Keep known lines visible beside an unknown line.

Each Context Menu row must use the same projected Total as its tooltip. It shows `???`
when the Total is unknown. Identification or an early Trait reveal updates the row and
tooltip without reopening the menu. Use the local approved visual for frame, spacing,
type, colors, and hierarchy. Keep tooltip logic independent of either chance.

Extend command option data beyond the current formatted label so the menu receives a
sanitized structured chance projection. Keep raw source IDs, signed hidden values, and
the actual execution result behind that boundary. Replace the menu's open-time-only
button construction with an update path that preserves hovered command identity and
tooltip placement. Recompute on knowledge, visible Intoxication, eligibility, target,
or Selected Cultist changes; close stale tooltips when their row/menu/target disappears.
Check positioning near viewport edges and over disabled rows without changing their
command availability. Do not attach hidden data as control metadata or help text.

Extend the normal Patron Profile projection and existing Patron Info Panel to show
learned Trait labels. Full identification shows the complete loadout. An early reveal
shows only the learned Trait and leaves other Profile facts unknown. Do not add empty
slots that disclose the hidden loadout count. Remove the existing normal-play Suspicion
band beside Mood to comply with CONTEXT and ADR 0006; preserve permitted debug and
Outcome views. Keep this a local change within the existing Green Folio layout.

Test actual rendered Profile content before identification, after each early reveal,
after identification, and after restart. Check that learning a Trait without a chance
modifier still makes it visible in the Profile. Test normal/debug/outcome information
boundaries and both 1024-width and larger layouts.

Test no modifiers, one known modifier, multiple known modifiers, an unknown positive
modifier, an unknown negative modifier, mixed known/unknown lines, Knock Out 5%/99%
clamps, Reason With 5%/95% clamps, identification, the Oblivious behavioral reveal, live
menu updates, menu/tooltip agreement, and sanitized accessibility text.

**Complete when:** one domain breakdown drives both commands and surfaces, and an unknown
Trait leaks no direction or total.

## Stage 8 — Grime presentation and Grime Inspection

Render patches on floor, table, and bar surfaces using the approved reference: flat,
irregular brown-grey stains with broken edges, restrained wet highlights, modest
footprint growth, and much stronger density/darkness growth. Keep Heavy patches local
and clip them to the authored surface. Use deterministic variants so reloads do not make
existing patches change shape.

Add patch picking that yields the Stage 5 Grime target and opens its Clean option through
the normal Context Menu. Test picking on each surface and among nearby actors/objects;
rendered stains alone are not acceptance. Removing a patch must clear its pick target,
open menu, tooltip, and outline without affecting nearby targets.

When a Patron is Inspected, outline every patch of that Patron's Sighted Grime with a thin
brass line. Pulse the line slightly with a slow, smooth opacity change. Keep the stain,
footprint, and gameplay state fixed during the pulse. Include patches below the Patron's
Satisfaction threshold and patches seen by a Slob. Remove outlines at once when
inspection closes, the inspected Patron changes or leaves, or the patch leaves sight.
Render no Grime panel, bar, threshold label, timer, seconds, number, or facing cone.

The simulation supplies patch snapshots and sighted patch IDs. The scene renders them and
owns the real-time decorative pulse. Pause may freeze or continue this decorative pulse,
but use one consistent rule and include it in visual review notes.

Create a focused review setup with Light, Moderate, Heavy, clustered, tabletop/bar,
Ruined Bathroom, below-threshold, Germaphobe-threshold, Slob, edge-of-cone, and
out-of-sight cases. Preserve the existing camera and Green Folio composition.

**Complete when:** the focused setup matches the approved stain reference and inspection
shows only slight pulsing outlines on the correct patches.

## Stage 9 — Integration and regression checks

Run the complete headless suite. Add integration coverage for a seeded flow:
Trait roll, hidden Knock Out modifier, identification, resolved tooltip, drink completion,
Grime creation, Grime Satisfaction pressure, Clean, recovery, Cigarette refusal/reveal,
Oblivious confusion/reveal, Reason With success, and Night restart. Use multiple Patrons
with valid loadouts: identification of the Knock Out subject must not pre-reveal the
Non-Smoker or Oblivious subject whose early reveal is under test. Exercise real command
and public-view seams; forced debug values may arrange a precondition but must not
perform the operation being asserted.

Extend `tests/presentation/test_production_scene_integration.gd` or add focused tests
beside it that load `scenes/prototypes/main_test.tscn`: pick a patch, open Clean, traverse
the Generated Move, finish Clean, and check the patch and reservations. Test live menu
and tooltip refresh with real controls. Verify both requested effects and preservation
of surrounding actors, navigation, surfaces, unrelated modifiers, and queue work.
Run the existing automated drink-order cycle; leave its manual counterpart to Stage 10.

Check at 1x, 2x, 4x, and Plain Pause wherever playback permits; Escape remains limited
to 1x and Pause. Never bypass that restriction to pass a test. Check 1024, 1280, and 1920 widths. Check both
selected Cultists, normal and Shift-queued Clean, every surface, bathroom blocking, and
Patron inspection changes. Check that normal HUD, hover summaries, debug-off views,
events, and accessibility text reveal no hidden values.

Summarize automated results, named tuning constants, changed domain seams, and all bugs
found during automated checks. Record new validation output separately from pre-existing
dirty artifacts; remove only noise this implementation generated. Do not run a broad
artifact cleanup. Report manual checks as pending until the user performs them.

**Complete when:** all automated checks pass with clean shutdown and the implementation
is ready for the user's manual review.

## Stage 10 — Human review and completion gate

The user performs all manual Godot reviews. Do not control the live Godot UI. Give the
user one focused checklist and the exact scene/build to open. The checklist must cover:

1. stain readability from Light through Heavy on floor, table, and bar;
2. restrained wet highlights and localized surface-clipped footprints;
3. slight brass pulse on every patch seen by the Inspected Patron;
4. immediate outline changes at the 5m and facing-cone boundaries;
5. no Grime In Sight panel, severity bar, threshold labels, or clean-time numbers;
6. unknown and resolved Modifier Tooltip states against the approved visual;
7. normal and Oblivious Hard-Evidence reactions, plus Reason With before and during Escape;
8. Smoking, Non-Smoker refusal/reveal, and the Clean Action at all speeds;
9. the normal Prepare Drink → Serve Order → Drinking → Socializing cycle.
10. learned Traits in the Profile, including each single-Trait reveal before identification;
11. Reason With cancellation without an attempt cost, and continuous same-/second-Cultist
    Intercept handoffs, success, and failure/resumption;
12. picking Grime and completing Clean on every surface, including a sub-two-second remainder.

Treat the visual as complete only after the user approves it. Apply requested local visual
changes, rerun affected automated checks, and return the revised checklist when needed.

**Complete when:** the user approves the Grime and Modifier Tooltip visuals and reports
the practical flow successful.

## Final deliverable

Provide a scoped commit or commits, the automated check results, the manual checklist,
all balance constants chosen for qualitative rules, and links to any intentional review
artifacts. Update `CONTEXT.md`, `docs/PROTOTYPE_GDD.md`, and `docs/TECHNICAL_DESIGN.md`
where their current rules conflict with the completed implementation. Update the design
file only if the user changes a settled rule. Remove superseded plans or text rather than
leaving stale documentation.

Stage only changes attributable to this implementation. Some required architecture files
are already untracked; inventory their baseline content and preserve it. Do not claim
ownership of unrelated work or include it through broad staging. Report the exact manual
scene/build and outstanding user review separately from completed automated work. Do
not mark Stage 10 complete or claim visual approval before the user supplies it.
