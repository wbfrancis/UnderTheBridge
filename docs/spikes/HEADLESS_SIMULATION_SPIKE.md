# Headless Simulation Spike

Status: **Pass — keep the approach**

Ticket: #3

Branch: `prototype/headless-simulation`

## Question

Can the prototype's time controls, seeded simulation, restart behavior, and Cultist Action Queue rules run deterministically without a rendered scene while remaining small enough for a lean, stable test suite?

## Result

Yes. Two engine-independent `RefCounted` modules expose the intended public seams and run under Godot 4.7.1 in headless mode:

- `GameSession`: start or restart a Night with a seed, choose pause/1x/2x/4x, advance simulation time, and take a snapshot.
- `CultistActionQueue`: append, do-now, remove a pending action, cancel the active action, advance, and take a snapshot.

The suite has six contract tests. It proves:

- pause, 1x, 2x, and 4x advance the same central simulated clock without rendering;
- identical Night seeds produce identical representative rolls and outcomes;
- restart resets the seed, clock, time scale, rolls, and outcome;
- each Cultist has one active action and at most three pending actions;
- pending actions can be removed and capacity is immediately reusable;
- do-now clears pending work and interrupts pre-Commitment work;
- do-now cannot interrupt post-Commitment work, so the urgent action waits next;
- active cancellation succeeds before Commitment and is rejected afterward;
- an invalid target fails visibly and the next queued action becomes active.

The representative rolls and success/failure result are a determinism tracer, not final gameplay rules or tuning.

## Reproduce

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test_headless.ps1
```

The command performs an import pass, then runs all tests below `res://tests` with GUT 9.7.1. The runner prefers the project's known Godot 4.7.1 console path, falls back to `godot` on `PATH`, and accepts an explicit `-GodotBin` override. Its editor and cache directories are isolated under `.godot/headless_profile`.

Pinned dependency:

- GUT 9.7.1
- upstream tag `v9.7.1`
- upstream commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`
- upstream license retained at `addons/gut/LICENSE.md`

## Architectural decisions

- Keep simulation state independent of Nodes, scenes, rendering, and real-time `Timer` ownership.
- Route UI commands through a small `GameSession` composition-root interface.
- Give each Cultist one Action Queue authority; UI reads snapshots rather than mutating internal arrays.
- Treat Commitment as the cancellation boundary and emit visible terminal events for failure, cancellation, and completion.
- Inject or query live target validity at the queue boundary in production; the spike's boolean validity field is only a controllable stand-in.
- Keep tests at these public seams. Add later scenario tests only for the accepted critical gameplay chains in the technical design.

## Deliberate omissions

This spike does not implement patrons, orders, bathrooms, suspicion, navigation, animation, HUD, actual win/loss logic, or production randomness. It does not test exact random values, UI layout, private helpers, tunable values in isolation, every action ordering, or every state permutation.

The isolated sandbox may print a harmless Windows root-certificate warning. Test success is determined by the GUT summary and process exit code.
