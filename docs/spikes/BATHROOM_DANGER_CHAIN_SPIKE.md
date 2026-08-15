# Bathroom danger-chain spike

## Question

Can the prototype's highest-risk bathroom chain run end to end—from seeded bathroom choice and FIFO occupancy through posture-sensitive Trapdoor use, missing-Companion escalation, Investigation, Escape, Intercept, defeat, cancellation, and restart—without stale interaction ownership or contradictory Patron terminal states?

## Scope

This is an isolated, inspectable proof for issue #5. It intentionally excludes production presentation, navigation travel, service, full perception, and the authored Night. The spike uses simulated durations and named interaction ownership so those later systems can integrate behind the already-approved interfaces.

The interactive evidence scene provides guided states for standing Capture, seated misfire, Investigation, Intercept, defeat, and restart. The headless model exposes full debug state after every command.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prototype_bathroom\run_spike.ps1
```

The command imports the project, runs the lean headless suite, writes `artifacts/bathroom_danger_chain/validation.json`, and captures `artifacts/bathroom_danger_chain/bathroom_danger_chain.png`.

## Evidence

- Seed `41904` produces repeatable bathroom-choice rolls.
- One bathroom occupant and two authored FIFO queue positions share the existing `InteractionRegistry` authority.
- Standing entry, standing exit, and standing Investigation are Trapdoor-vulnerable.
- Seated occupants are protected. Sober witnesses receive maximum Hard Evidence and begin Escape; Max Drunk witnesses receive recoverable `+25` Suspicion.
- A Trapdoor activation remembers only the occupant present at activation. Its two-second pulse cannot capture a newly promoted occupant, and its three-second cooldown returns to closed.
- Missing-Companion milestones apply `+25` at 20 seconds, `+25` at 30 seconds, and maximum Suspicion with Investigation at 40 seconds.
- Investigation waits for a current occupant, bypasses the ordinary queue, searches standing for five seconds, and becomes Escape if unresolved.
- Escape requests 1x, permits one five-second Intercept, and records immediate defeat at the front exit.
- Capture, cancellation, completed Intercept, defeat, and restart release their bathroom, queue, wait, intercept, and front-exit ownership.
- The focused bathroom proof adds four scenarios. The complete headless suite passes 11 tests and 104 assertions.

## Verdict

**Keep the state rules and module boundaries.** The accepted chain is internally consistent and can proceed to narrow production slices.

The spike orchestration class is deliberately not the production architecture. During integration:

- `PatronAgent` owns Patron lifecycle, activity, posture, Bladder, Suspicion, and missing-Companion knowledge.
- `InteractionRegistry` remains the sole owner of bathroom, FIFO queue, Investigation wait, front-exit, and Intercept reservations.
- `PerceptionSystem` creates the seated Hard Evidence and nearby Trapdoor sound stimuli.
- `NightDirector` owns the forced 1x request and terminal defeat.
- `GameSession` composes those modules and exposes normal/debug snapshots; the UI submits commands and renders snapshots only.

The Trapdoor must retain the activation-time occupant identifier for the open pulse. This is the smallest reliable rule preventing a pulse from becoming an armed future hazard after Capture, cancellation, or queue promotion.

## Not proven here

- Navigation travel time and collision around the bathroom; ticket #4 proved the general navigation/reservation mechanics separately.
- Visual facing, line of sight, or room hearing.
- Full-Night service interactions and group schedules.
- Final animation, audio, or player-facing information design.
- Exhaustive combinations of tuneable timings and Patron conditions.
