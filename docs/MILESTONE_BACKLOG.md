# Under the Bridge — Milestone Backlog

## 1. Delivery shape

- Four implementation weeks
- One evaluation/revision week
- Windows desktop, Godot 4.7.1, typed GDScript, Blender 5.2
- Three Cultists, eight authored Patrons, one 18-minute Night
- No gameplay implementation begins until this planning baseline is approved and committed

## 2. Global definition of done

A backlog item is done when:

- its player-visible result matches the GDD
- runtime ownership and module interface match the technical design
- cancellation, restart, and terminal-state cleanup are considered
- relevant critical-path tests pass; no exhaustive branch coverage is required
- debug-only instrumentation is removed or clearly gated
- tuning values live in definitions rather than scattered scripts
- the change runs at pause, 1x, 2x, and 4x where applicable
- no new v1 scope is introduced

## 3. Milestone 0 — Planning and repository baseline

**Goal:** Create a reproducible planning baseline before Godot content exists.

Backlog:

- M0-01 Create GDD, migration guide, technical design, asset manifest, and milestone backlog.
- M0-02 Create the domain glossary and project index.
- M0-03 Initialize Git with `main`, Godot ignores, and Git LFS rules.
- M0-04 Commit the planning baseline.
- M0-05 Confirm Godot 4.7.1 and Blender 5.2 launch locally.

Definition of done:

- Documents agree on timings, formulas, terminology, and scope.
- Repository contains no Godot cache or Unreal binary content.
- Clean status follows the baseline commit.

## 4. Milestone 1 — Week 1: risk spikes and foundation

**Goal:** Retire the four highest technical risks before full feature construction.

### Spike 1: visual/import

- Create a migration copy of a representative `Speakeasy.blend` section.
- Import with referenced textures.
- Establish meter scale, camera angle, pixel filtering, Sprite3D scale, lighting, transparency, and occlusion.
- Compare glass, mirror, lamp glass, and specular materials.

Exit condition: the 2.5D look is readable and the import is reproducible without maintaining a separate manual `.glb`.

### Spike 2: movement and interactions

- Greybox room, hallway, bar, bathroom, and exit.
- Move 11 agents with `NavigationAgent3D` at 1x and 4x.
- Add seat/bar reservations and two authored bathroom queue positions.
- Exercise cancellation and reservation cleanup.

Exit condition: a ten-minute stress run completes without a stuck agent, duplicate slot ownership, or unreleased reservation.

### Spike 3: headless simulation

- Establish central simulation clock and seeded random source.
- Exercise Action Queue semantics, Order timing, Suspicion events, Friendship, stay-behind, and outcomes without finished art.
- Pin GUT 9.7.1 and add only the accepted critical rule/module tests.

Exit condition: repeated seeds produce repeatable results and the lean headless suite runs from one command.

### Spike 4: end-to-end danger chain

- Implement isolated bathroom occupancy and posture.
- Add Trapdoor pulse/cooldown and seated witness exception.
- Add missing Companion milestones, Investigation, Intercept, Escape, and defeat.

Exit condition: the full bathroom chain succeeds, fails, cancels, and restarts cleanly without bypassing module interfaces.

Milestone definition of done:

- All spike decisions are recorded in the relevant planning document.
- Any failed assumption changes the plan before production code grows around it.
- A minimal `GameSession` composition root and planned folder structure exist.

## 5. Milestone 2 — Week 2: service and command game

**Goal:** Make a complete non-capture Night playable.

Backlog:

- M2-01 Selection, Cultist switching, selected-Cultist HUD queue, per-row `x` removal/cancellation, append, do-now, Commitment Point disabling, and failure reasons.
- M2-02 Camera pan/zoom and mouse/keyboard input map.
- M2-03 `InteractionRegistry` for seats, bar positions, bathroom, queues, and front exit.
- M2-04 Fixed Arrival Group schedule and seating.
- M2-05 Patron normal loop: seat, Order, drink, socialize, Bladder, seeded 5-second bathroom-choice checks, bathroom, Intoxication decay, and Normal Departure.
- M2-06 `OrderSystem`: automatic Orders, 5-second preparation, physical drinks, delivery, payment, tips, impatience, cancellation.
- M2-07 Safe service autonomy for empty Cultist queues.
- M2-08 Pause, 1x, 2x, 4x, Closing, results shell, and clean restart.
- M2-09 Separate normal/debug Patron data views and minimal selected-Patron/selected-Cultist UI; normal play must not expose Bladder or hidden numeric state.

Key verification:

- One Action Queue contract test.
- Exclusive reservation/FIFO bathroom test.
- Served versus cancelled Order test.
- Manual ten-minute service Night at 1x/4x with no stuck actor.

Definition of done:

- Eight Patrons arrive and complete plausible non-capture visits.
- Drinks produce cash and Bladder/Intoxication changes.
- Failed service produces the specified mood/Suspicion/Departure effects.
- Restart creates a clean second Night.

## 6. Milestone 3 — Week 3: danger, relationships, and four captures

**Goal:** Implement the complete service-versus-capture tension.

Backlog:

- M3-01 Personal Suspicion bands, event values, cause classification, recovery, visible status, and Max Drunk Hard Evidence downgrade.
- M3-02 Visual line of sight, room hearing, Unattended Body pressure, and companion influence.
- M3-03 Trapdoor route integrated into the full Night.
- M3-04 Drugged Drink: two doses, preparation, countdown, drowsiness, collapse.
- M3-05 Helper behavior, front-exit carrying, Rescue Persuasion roll, dual Capture.
- M3-06 Manual knockout, hearing/visual evidence, dragging, drop, and Tunnel Intake.
- M3-07 Cigarette, sustained conversation, Friendship bands, and deterministic Friendship Capture.
- M3-08 Investigation, Escape, forced 1x, Intercept, and immediate defeat.
- M3-09 Group Normal Departure, departure anchor, and stay-behind rolls.

Key verification:

- Representative formula bounds and seeded odds.
- Seated/standing Trapdoor scenario plus Max Drunk Hard Evidence downgrade.
- Missing Companion through Investigation/Escape/defeat scenario.
- Drug collapse Helper success/failure scenario.
- Action cancellation around knockout Commitment Point and drag drop.

Definition of done:

- All four Capture routes can complete in a full Night.
- Each route creates its specified witness and companion consequences.
- The player can understand the cause of Investigation and Escape.
- No autonomous behavior initiates Capture.

## 7. Milestone 4 — Week 4: vertical-slice integration and tuning

**Goal:** Produce a stable, legible evaluation build.

Backlog:

- M4-01 Finish the authored eight-Patron profiles, companion links, mood/value/risk labels, and arrival data.
- M4-02 Add minimal sprite variants and required animation states.
- M4-03 Complete room dressing needed for readable routes; preserve greybox where polish adds no evaluation value.
- M4-04 Finalize HUD, urgent icons, critical Escape alert, exact persuasion chance, and results metrics.
- M4-05 Tune service cadence, movement speed, bathroom pressure, Suspicion recovery, and capture timings without changing core rules.
- M4-06 Run ten clean restart cycles and fix state leakage.
- M4-07 Package a Windows evaluation build and playtest instructions.

Key verification:

- Quota success, quota failure, and maximum-Suspicion defeat.
- Clean restart contract.
- Ten-minute 11-agent stability run.
- Smoke test all capture routes in packaged build.

Definition of done:

- One Night lasts about 15-25 real minutes under normal speed-control use.
- Three Captures and Closing produce success.
- Maximum-Suspicion Escape produces immediate defeat.
- Results accurately report the accepted metrics.
- Build is stable enough for unassisted first attempts.

## 8. Milestone 5 — Week 5: evaluation and decision

**Goal:** Decide whether the core fantasy deserves expansion.

Backlog:

- M5-01 Run at least eight observed sessions across four people.
- M5-02 Record first-attempt comprehension and second-attempt mastery.
- M5-03 Record Capture routes used, failures, Suspicion explanations, session length, technical failures, and replay desire.
- M5-04 Compare evidence with GDD evaluation gates.
- M5-05 Choose continue, one-week revision, or stop/reframe.

Definition of done:

- Six of eight sessions complete without technical blockage.
- Three of four testers explain Suspicion and counterplay.
- All four Capture routes succeed across the set.
- Three of four identify service-versus-capture as the appeal and want another Night.
- No route dominates every alternative.
- A written go/no-go decision exists before adding content.

## 9. Risk register

| Risk | Impact | Early signal | Mitigation / decision point |
|---|---|---|---|
| Pixel sprites look detached from 3D room | Core aesthetic fails | Visual spike reads like placeholders rather than a style | Tune camera, scale, filtering, shadows, and lighting before gameplay art. |
| Blender import is unstable or visually wrong | Environment work repeats | Transform/material changes on reimport | Clean migration copy; keep relative textures; record overrides; use `.glb` only if direct import fails. |
| High-poly repeated props hurt performance | 4x crowd simulation suffers | GPU/frame-time spike with room visible | Instance or reduce measured offenders only. |
| Eleven agents jam in hallway/bathroom | Core simulation deadlocks | Unreleased reservations or avoidance oscillation | Authored approach/queue points, reservation invariants, 10-minute stress run. |
| 4x time causes skipped interactions | Commands feel unreliable | Overshoot, duplicate completion, timer disagreement | Central clock and idempotent completion; spike implementation choice. |
| State combinations become unmaintainable | Bugs and test churn | Parallel booleans contradict lifecycle state | Hierarchical Patron lifecycle plus orthogonal needs; single authority. |
| Test suite mirrors implementation | Small tuning changes become expensive | Many brittle tests change with refactors | Test only module interfaces and critical chains; add regression tests after real failures. |
| Four Capture routes exceed four weeks | Slice ships incomplete | Week 3 starts without stable service loop | Cut polish and optional presentation first; do not expand routes or content. |
| Character art scope expands | Gameplay time becomes art production | Multiple directions/frames requested before evaluation | Minimal state silhouettes and palette variants only. |
| Suspicion is opaque | Loss feels arbitrary | Testers cannot explain cause | Visible bands, urgent icons, event feedback, observed first attempts. |
| One route dominates | Target selection becomes trivial | Repeated safest/faster route | Tune time, witness risk, resource limits, and social prerequisites during Week 4. |
| OneDrive/Git/LFS interaction creates friction | Repository instability | sync conflicts in `.git` or large binaries | Keep generated files ignored, commit often, and choose a remote backup before production expansion. |

## 10. Scope-cut order

If the schedule slips, cut in this order:

1. environmental polish not needed for readability
2. extra animation frames and cosmetic variants
3. optional score presentation beyond required results metrics
4. nonessential sound and visual flourishes

Do not cut the service loop, personal Suspicion, companion behavior, Action Queues, bathroom Trapdoor, dragging, or any of the four evaluation Capture routes without explicitly redefining the prototype question.
