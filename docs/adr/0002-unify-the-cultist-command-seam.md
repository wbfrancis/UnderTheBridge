# Unify the Cultist command seam

Player input reaches gameplay through one deep module, `CultistCommandSystem`. It owns the command catalog, the Action Queue lifecycle, target revalidation, the approach stage, the Commitment Point, execution dispatch, and reservation cleanup. Move and every contextual command cross the same interface, so one Cultist has exactly one active Action and at most three pending Actions no matter which command produced them.

`GameSession` stays the gameplay authority. It answers `command_availability` for every command and it runs every operation. The command seam never restates a rule; it asks. The live scene is a thin adapter: it picks targets, renders the menu and markers, drives `NavigableActor3D`, and forwards navigation callbacks.

Target references are serializable — target kind, target id, live position, and the authored approach slot. No scene node enters domain state, so the module is testable headlessly and the same interface serves a future save format.

## Considered Options

- Separate movement and context queues were rejected. `CultistMovementPlan` and `GameSession` each held their own `CultistActionQueue`, so a Move and a contextual command could both believe they owned the Cultist. Interleaving them correctly needs one ordering authority, and the four-Action limit only means something when one queue counts every Action.
- Eligibility branches in the context menu were rejected. Duplicating the preconditions in UI `if` statements makes the menu and the operation disagree the moment either changes. The menu now renders the command descriptions the seam returns.
- Reserving the approach slot at queue time was rejected in favor of reserving at activation. Reserving early would hold a work position for an Action that has not started, which is a hidden wait queue by another name. A contention loss is now a visible rejection at the moment the Action becomes active.
