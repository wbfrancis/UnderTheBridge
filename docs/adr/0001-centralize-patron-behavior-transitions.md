# Centralize Patron behavior transitions

Every character uses an Action Queue owned by `CharacterActionSystem`. `PatronIntentPlanner` selects and defers Patron intents through the transition table; `PatronActionCoordinator` applies those decisions to the shared queue and releases obsolete reservations. The simulation owns gameplay effects, while the queue owns Action identity and elapsed time. This replaces separate Patron state-machine timing and Cultist queue ownership, so interruption and debug controls use the same lifecycle.

Step Aside pauses the current Action without changing its identity or elapsed time. Completion resumes that Action at the new position; terminal transitions clear active, paused, and pending work together. Patron queues remain hidden from players, but debug mode permits cancellation, forced completion, clearing, and planner pause without reversing effects already applied.

## Considered Options

- Scattered conditional checks were rejected because each new behavior would need changes across unrelated routines.
- A behavior tree was rejected because the prototype needs explicit, reproducible transitions and Commitment rules rather than continuous goal scoring.
- One class per state was rejected because it creates a wide, shallow interface for a small fixed state set.
