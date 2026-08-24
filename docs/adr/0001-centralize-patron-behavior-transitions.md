# Centralize Patron behavior transitions

Patron routines, urgent behavior, and committed activities use one table-driven hierarchical state machine behind the `PatronBehaviorMachine` interface. The module accepts intents, advances simulated time, and returns events and snapshots; it owns transition priority, preemption, deferral, state entry and exit, and reservation cleanup. This keeps transition rules local and testable instead of spreading conditional branches across routines, while Cultist Actions continue to use the existing Command pattern.

## Considered Options

- Scattered conditional checks were rejected because each new behavior would need changes across unrelated routines.
- A behavior tree was rejected because the prototype needs explicit, reproducible transitions and Commitment rules rather than continuous goal scoring.
- One class per state was rejected because it creates a wide, shallow interface for a small fixed state set.
